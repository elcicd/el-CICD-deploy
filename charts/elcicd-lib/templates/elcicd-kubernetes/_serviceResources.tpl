{{/*
  Defines templates for rendering Kubernetes workload resources, including:
  - Ingress
  - Service

  In the following documentation:
  - HELPER KEYS - el-CICD template specific keys keys that can be used with that are NOT part of the Kubernetes
    resource, but rather conveniences to make defining Kubernetes resoruces less verbose or easier
  - DEFAULT KEYS - standard keys for the the Kubernetes resource, usually located at the top of the
    resource defintion or just under a standard catch-all key like "spec"
  - el-CICD SUPPORTING TEMPLATES - el-CICD templates that are shared among different el-CICD templates
    and called to render further data; e.g. every template calls "elcicd-common.apiObjectHeader", which
    in turn renders the metadata section found in every Kubernetes resource
*/}}

{{/*
  ======================================
  elcicd-kubernetes.ingress
  ======================================

  PARAMETERS LIST:
    . -> should always be root of chart
    $ingressValues -> elCicd template for Ingress

  ======================================

  HELPER KEYS
  ---
  [spec]:
    [rules]:
      - host -> .Values.elCicdDefaults.ingressHostDomain
        [paths]:
        - path -> default .Values.elCicdDefaults.ingressRulePath
          pathType -> default .Values.elCicdDefaults.ingressRulePathType
          [backend]:
            [service]:
              name -> $<OBJ_NAME>
              [port]:
                number -> $ingressValues.port | default $.Values.elCicdDefaults.port
  ---
  [spec]:
    [tls]:
    - secretName -> { if $ingressValues.allowHttp == false }

  ======================================

  DEFAULT KEYS
  ---
    [spec]:
      defaultBackend
      ingressClassName
      rules
      tls

  ======================================

  el-CICD SUPPORTING TEMPLATES:
    "elcicd-common.apiObjectHeader"

  ======================================

  Defines a el-CICD template for a Kubernetes Ingress.
*/}}
{{- define "elcicd-kubernetes.ingress" }}
{{- $args := . }}
{{- $ := get $args "$" }}
{{- $ingressValues := get $args "elCicdTemplate" }}


{{- $_ := set $ingressValues "kind" "Ingress" }}
{{- $_ := set $ingressValues "apiVersion" ($ingressValues.apiVersion | default "networking.k8s.io/v1") }}
{{- $_ := set $ingressValues "annotations" ($ingressValues.annotations | default dict) }}
{{- if $ingressValues.allowHttp }}
  {{- $_ := set $ingressValues.annotations
                  "kubernetes.io/ingress.allow-http"
                  (eq (toString $ingressValues.allowHttp) "true" | quote)
  }}
{{- end }}
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
  {{- else }}
  tls:
  - secretName: {{ $ingressValues.secretName }}
  {{- end }}
{{- end }}

{{/*
  ======================================
  elcicd-kubernetes.service
  ======================================

  PARAMETERS LIST:
    . -> should always be root of chart
    $svcValues -> elCicd template for Service

  ======================================

  HELPER KEYS
  ---
  [spec]:
    selector
    ports
  ---
  [spec]:
    [ports]:
    - name- > $<OBJ_NAME>-port
      port -> .Values.elCicdDefaults.port
      targetPort
      protocol -> .Values.elCicdDefaults.protocol
  ---
  { if $svcValues.prometheus.port | .Values.usePrometheus }
  [metadata]:
    [annotations]:
      [prometheus.io/path] -> $svcValues.prometheus.path |  .Values.elCicdDefaults.prometheusPath
      [prometheus.io/port] -> $svcValues.prometheus.port | $svcValues.port
      [prometheus.io/scheme] -> $svcValues.prometheus.scheme | .Values.elCicdDefaults.prometheusScheme
      [prometheus.io/scrape] -> $svcValues.prometheus.scrape | .Values.elCicdDefaults.prometheusScrape
  {{- end }}
  ---
  { if $svcValues.prometheus.port | .Values.usePrometheus }
  [spec]:
    [ports]:
    - [name]: prometheus-port
      [port]: $svcValues.prometheus.port | .Values.elCicdDefaults.prometheusPort
      [protocol]: $svcValues.prometheus.protocol | .Values.elCicdDefaults.prometheusProtocol

  ======================================

  el-CICD SUPPORTING TEMPLATES:
    "elcicd-common.apiObjectHeader"
    "elcicd-kubernetes.prometheusAnnotations" 

  ======================================

  Defines a el-CICD template for a Kubernetes Service.
*/}}
{{- define "elcicd-kubernetes.service" }}
{{- $args := . }}
{{- $ := get $args "$" }}
{{- $svcValues := get $args "elCicdTemplate" }}

{{- if or ($svcValues.prometheus).port $.Values.usePrometheus }}
  {{- include "elcicd-kubernetes.prometheusAnnotations" . }}
{{- end }}
{{- if or $svcValues.threeScalePort $.Values.use3Scale }}
  {{- include "elcicd-kubernetes.3ScaleAnnotations" . }}
  {{- $_ := set $svcValues "labels" ($svcValues.labels  | default dict) }}
  {{- $_ := set $svcValues.labels "discovery.3scale.net" true }}
{{- end }}
{{- $_ := set $svcValues "kind" "Service" }}
{{- include "elcicd-common.apiObjectHeader" . }}
spec:
  selector:
    elcicd.io/selector: {{ include "elcicd-common.elcicdLabels" . }}
    {{- range $key, $value := $svcValues.selector }}
    {{ $key }}: {{ $value }}
    {{- end }}
  ports:
  {{- if and $svcValues.ports $svcValues.port }}
    {{- fail "A Service cannot define both port and ports values!" }}
  {{- end }}
  {{- if $svcValues.ports }}
    {{- $svcValues.ports | toYaml | nindent 2 }}
  {{- else }}
  - name: {{ $svcValues.objName }}-port
    port: {{ $svcValues.port | default $.Values.elCicdDefaults.port }}
    {{- if or $svcValues.targetPort $svcValues.containerPort }}
    targetPort: {{ $svcValues.targetPort | default $svcValues.containerPort }}
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