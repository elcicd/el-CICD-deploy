{{/*
Ingress
*/}}
{{- define "elcicd-kubernetes.ingress" }}
{{- $ := index . 0 }}
{{- $ingressValues := index . 1 }}
{{- $_ := set $ingressValues "kind" "Ingress" }}
{{- $_ := set $ingressValues "apiVersion" "networking.k8s.io/v1" }}
{{- $_ := set $ingressValues "annotations" ($ingressValues.annotations | default dict) }}
{{- $_ := set $ingressValues "allowHttp" ($ingressValues.allowHttp | default "false") }}
{{- $_ := set $ingressValues.annotations "kubernetes.io/ingress.allow-http" $ingressValues.allowHttp }}
{{- include "elcicd-common.apiObjectHeader" . }}
spec:
  {{- $whiteList := list "defaultBackend"	
                         "ingressClassName"	}}
  {{- include "elcicd-common.outputToYaml" (list $ $ingressValues $whiteList) }}
  {{- if $ingressValues.rules }}
  rules: {{- $ingressValues.rules | toYaml | nindent 4 }}
  {{- else }}
  rules:
  {{- if (not $ingressValues.host) }}
    {{- $defaultIngressHostDomain := $.Values.elCicdDefaults.ingressHostDomain }}
    {{- if (regexMatch "^[\\w]" $defaultIngressHostDomain) }}
      {{- $defaultIngressHostDomain = (printf ".%s" $defaultIngressHostDomain) }}
    {{- end }}
    {{- $_ := set $ingressValues "host" (printf "%s%s" $ingressValues.objName $defaultIngressHostDomain) }}
  {{- end }}
  - host: {{ $ingressValues.host }}
    http:
      paths:
      - path: {{ $ingressValues.path | default $.Values.elCicdDefaults.ingressRulePath }}
        pathType: {{ $ingressValues.pathType | default $.Values.elCicdDefaults.ingressRulePathType }}
        backend:
          service:
            name: {{ $ingressValues.objName }}
            port:
              number: {{ $ingressValues.port | default $.Values.elCicdDefaults.port }}
  {{- end }}
  {{- if $ingressValues.tls }}
  tls: {{ $ingressValues.tls | toYaml | nindent 4 }}
  {{- else if or $ingressValues.secretName (eq $ingressValues.allowHttp "false") }}
  tls:
  - secretName: {{ $ingressValues.secretName }}
  {{- end }}
{{- end }}

{{/*
Service
*/}}
{{- define "elcicd-kubernetes.service" }}
{{- $ := index . 0 }}
{{- $svcValues := index . 1 }}
{{- if or ($svcValues.prometheus).port $.Values.usePrometheus }}
  {{- include "elcicd-kubernetes.prometheusAnnotations" . }}
{{- end }}
{{- if or $svcValues.threeScalePort $.Values.use3Scale }}
  {{- include "elcicd-kubernetes.3ScaleAnnotations" . }}
  {{- $_ := set $svcValues "labels" ($svcValues.labels  | default dict) }}
  {{- $_ := set $svcValues.labels "discovery.3scale.net" true }}
{{- end }}
{{- $_ := set $svcValues "kind" "Service" }}
{{- $_ := set $svcValues "apiVersion" "v1" }}
{{- include "elcicd-common.apiObjectHeader" . }}
spec:
  selector:
    {{- include "elcicd-common.elcicdLabels" . | indent 4 }}
    {{- range $key, $value := $svcValues.selector }}
    {{ $key }}: {{ $value }}
    {{- end }}
  ports:
  {{- if and (or ($svcValues.service).ports $svcValues.ports) $svcValues.port }}
    {{- fail "A Service cannot define both port and ports values!" }}
  {{- end }}
  {{- if or $svcValues.ports ($svcValues.service).ports }}
    {{- (($svcValues.service).ports | default $svcValues.ports) | toYaml | nindent 2 }}
  {{- else }}
  - name: {{ $svcValues.objName }}-port
    port: {{ $svcValues.port | default $.Values.elCicdDefaults.port }}
    {{- if $svcValues.targetPort }}
    targetPort: {{ $svcValues.targetPort }}
    {{- end }}
    {{- if or $svcValues.protocol $.Values.elCicdDefaults.protocol }}
    protocol: {{ $svcValues.protocol | default $.Values.elCicdDefaults.protocol }}
    {{- end }}
  {{- end }}
  {{- if or ($svcValues.prometheus).port $svcValues.usePrometheus }}
  - name: prometheus-port
    port: {{ ($svcValues.prometheus).port | default $.Values.elCicdDefaults.prometheusPort }}
    {{- if or ($svcValues.prometheus).protocol $.Values.elCicdDefaults.prometheusProtocol }}
    protocol: {{ ($svcValues.prometheus).protocol | default $.Values.elCicdDefaults.prometheusProtocol }}
    {{- end }}
  {{- end }}
{{- end }}