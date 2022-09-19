{{/*
Deployment and Service combination
*/}}
{{- define "elCicdResources.deploymentService" }}
  {{- include "elCicdResources.deployment" . }}
---
  {{- include "elCicdResources.service" . }}
{{- end }}
{{/*
Deployment and Service combination
*/}}
{{- define "elCicdResources.deploymentServiceIngress" }}
  {{- include "elCicdResources.deployment" . }}
---
  {{- include "elCicdResources.service" . }}
---
  {{- include "elCicdResources.ingress" . }}
{{- end }}


{{/*
Job Template
*/}}
{{- define "elCicdResources.jobTemplate" }}
{{- $ := index . 0 }}
{{- $jobValues := index . 1 }}
{{- include "elCicdResources.apiMetadata" . }}
spec:
  {{- $whiteList := list "activeDeadlineSeconds"
                         "backoffLimit"
                         "completionMode"
                         "completions"
                         "manualSelector"
                         "parallelism"
                         "ttlSecondsAfterFinished" }}
  {{- include "elCicdResources.outputToYaml" (list $jobValues $whiteList) }}
  template: {{ include "elCicdResources.podTemplate" (list $ $jobValues false) | nindent 4 }}
{{- end }}

{{/*
Pod Template
*/}}
{{- define "elCicdResources.podTemplate" }}
{{- $ := index . 0 }}
{{- $podValues := index . 1 }}
{{- include "elCicdResources.apiMetadata" . }}
spec:
  {{- $whiteList := list  "activeDeadlineSeconds"
                          "affinity"
                          "automountServiceAccountToken"
                          "dnsConfig"
                          "dnsPolicy"
                          "enableServiceLinks"
                          "hostAliases"
                          "hostIPC"
                          "hostNetwork"
                          "hostPID"
                          "hostname"
                          "nodeName"
                          "nodeSelector"
                          "os"
                          "overhead"
                          "preemptionPolicy"
                          "priority"
                          "priorityClassName"
                          "readinessGates"
                          "restartPolicy"
                          "runtimeClassName"
                          "schedulerName"
                          "serviceAccount"
                          "serviceAccountName"
                          "setHostnameAsFQDN"
                          "shareProcessNamespace"
                          "subdomain"
                          "terminationGracePeriodSeconds"
                          "tolerations"
                          "topologySpreadConstraints" }}
  {{- include "elCicdResources.outputToYaml" (list $podValues $whiteList) }}
  containers:
    {{- $containers := prepend ($podValues.sidecars | default list) $podValues }}
    {{- include "elCicdResources.containers" (list $ $containers) | trim | nindent 2 }}
  {{- if $podValues.ephemeralContainers }}
  ephemeralContainers:
    {{- include "elCicdResources.containers" (list $ $podValues.ephemeralContainers false) | trim | nindent 2 }}
  {{- end }}
  {{- $_ := set $podValues "imagePullSecrets" ($podValues.imagePullSecrets | default $.Values.global.defaultImagePullSecrets) }}
  {{- $_ := set $podValues "imagePullSecret" ($podValues.imagePullSecret | default $.Values.global.defaultImagePullSecret) }}
  {{- if $podValues.imagePullSecrets }}
  imagePullSecrets:
    {{- range $secretName := $podValues.imagePullSecrets }}
  - name: {{ $secretName }}
    {{- end }}
  {{- else if $podValues.imagePullSecret }}
  imagePullSecrets:
  - name: {{ $podValues.imagePullSecret }}
  {{- end }}
  {{- if $podValues.initContainers }}
  initContainers:
    {{- include "elCicdResources.containers" (list $ $podValues.initContainers false) | trim | nindent 2 }}
  {{- end }}
  {{- if $podValues.securityContext }}
  securityContext: {{ $podValues.securityContext | toYaml | nindent 4 }}
  {{- else }}
  securityContext:
    runAsNonRoot: true
    {{- if not $.Values.useLegacyPodSecurityContextDefault }}
    seccompProfile:
      type: RuntimeDefault
    {{- end }}
  {{- end }}
{{- end }}

{{/*
Container definition
*/}}
{{- define "elCicdResources.containers" }}
{{- $ := index . 0 }}
{{- $containers := index . 1 }}
{{- range $containerVals := $containers }}
- {{- $whiteList := list "args"
                         "command"
                         "env"
                         "envFrom"
                         "lifecycle"
                         "livenessProbe"
                         "readinessProbe"
                         "startupProbe"
                         "stdin"
                         "stdinOnce"
                         "terminationMessagePath"
                         "terminationMessagePolicy"
                         "tty"
                         "volumeDevices"
                         "volumeMounts"
                         "workingDir" }}
  {{- include "elCicdResources.outputToYaml" (list $containerVals $whiteList) }}
  name: {{ $containerVals.name | default $containerVals.appName }}
  image: {{ $containerVals.image | default $.Values.global.defaultImage }}
  imagePullPolicy: {{ $containerVals.imagePullPolicy | default $.Values.global.defaultImagePullPolicy }}
  {{- if or $containerVals.ports $containerVals.port $.Values.global.defaultPort $containerVals.usePrometheus }}
  ports:
    {{- if and $containerVals.ports $containerVals.port }}
      {{- fail "A Container cannot define both port and ports values!" }}
    {{- end }}
    {{- if $containerVals.ports }}
      {{- $containerVals.ports | toYaml | nindent 2 }}
    {{- else if or $containerVals.port $.Values.global.defaultPort }}
  - name: default-port
    containerPort: {{ $containerVals.port | default $.Values.global.defaultPort }}
    protocol: {{ $containerVals.protocol | default $.Values.global.defaultProtocol }}
    {{- end }}
    {{- if or ($containerVals.prometheus).port (and $containerVals.usePrometheus $.Values.global.defaultPrometheusPort) }}
  - name: prometheus-port
    containerPort: {{ ($containerVals.prometheus).port | default $.Values.global.defaultPrometheusPort }}
    protocol: {{ ($containerVals.prometheus).protocol | default ($.Values.global.defaultPrometheusProtocol | default $.Values.global.defaultProtocol) }}
    {{- end }}
  {{- end }}
  resources:
    limits:
      cpu: {{ $containerVals.limitsCpu | default (($containerVals.resources).limits).cpu | default $.Values.global.defaultLimitsCpu }}
      memory: {{ $containerVals.limitsMemory | default (($containerVals.resources).limits).memory | default $.Values.global.defaultLimitsMemory }}
      {{- range $limit, $value := ($containerVals.resources).limits }}
        {{- if and (ne $limit "cpu") (ne $limit "memory") }}
      {{ $limit }}: {{ $value }}
        {{- end }}
      {{- end }}
    requests:
      cpu: {{ $containerVals.requestsCpu | default (($containerVals.resources).requests).cpu | default $.Values.global.defaultRequestsCpu }}
      memory: {{ $containerVals.requestsMemory | default (($containerVals.resources).requests).memory | default $.Values.global.defaultRequestsMemory }}
      {{- range $limit, $value := ($containerVals.resources).requests }}
        {{- if and (ne $limit "cpu") (ne $limit "memory") }}
      {{ $limit }}: {{ $value }}
        {{- end }}
      {{- end }}
  {{- if $containerVals.securityContext }}
  securityContext: {{ $containerVals.securityContext | toYaml | nindent 4 }}
  {{- else }}
  securityContext:
    allowPrivilegeEscalation: false
    capabilities:
      drop:
      - ALL
  {{- end }}
{{- end }}
{{- end }}

{{/*
Service Prometheus Annotations definition
*/}}
{{- define "elCicdResources.svcPrometheusAnnotations" }}
  {{- $ := index . 0 }}
  {{- $svcValues := index . 1 }}
  {{- $_ := set $svcValues "annotations" ($svcValues.annotations | default dict) }}

  {{- if or ($svcValues.prometheus).path $.Values.global.defaultPrometheusPath }}
    {{- $_ := set $svcValues.annotations "prometheus.io/path" ($svcValues.prometheus.path | default $.Values.global.defaultPrometheusPath) }}
  {{- end }}

  {{- if or ($svcValues.prometheus).port $.Values.global.defaultPrometheusPort }}
    {{- $_ := set $svcValues.annotations "prometheus.io/port" ($svcValues.prometheus.port | default $svcValues.port) }}
  {{- end }}

  {{- if or ($svcValues.prometheus).scheme $.Values.global.defaultPrometheusScheme }}
    {{- $_ := set $svcValues.annotations "prometheus.io/scheme" ($svcValues.prometheus.scheme | default $.Values.global.defaultPrometheusScheme) }}
  {{- end }}

  {{- if or ($svcValues.prometheus).scrape $.Values.global.defaultPrometheusScrape }}
    {{- $_ := set $svcValues.annotations "prometheus.io/scrape" ($svcValues.prometheus.scrape | default $.Values.global.defaultPrometheusScrape) }}
  {{- end }}
{{- end }}

{{/*
Service Prometheus 3Scale definition
*/}}
{{- define "elCicdResources.3ScaleAnnotations" }}
  {{- $ := index . 0 }}
  {{- $svcValues := index . 1 }}
  {{- $_ := set $svcValues "annotations" ($svcValues.annotations | default dict) }}
  {{- $_ := set $svcValues.annotations "discovery.3scale.net/path" ($svcValues.threeScale.port | default $svcValues.port | default $.Values.global.defaultPort) }}
  {{- $_ := set $svcValues.annotations "discovery.3scale.net/port" ($svcValues.threeScale.path | default $.Values.global.default3ScalePath) }}
  {{- $_ := set $svcValues.annotations "discovery.3scale.net/scheme" ($svcValues.threeScale.scheme | default $.Values.global.default3ScaleScheme) }}
{{- end }}