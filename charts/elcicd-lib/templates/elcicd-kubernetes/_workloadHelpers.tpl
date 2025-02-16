{{/*
  Helper templates for rendering Kubernetes workload resources, including:
  - CronJob
  - Deployment
  - HorizontalPodAutoscaler
  - Job
  - StatefulSet

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
General k8s selector definition.
*/}}
{{- define "elcicd-kubernetes.labelSelector" }}
{{- $ := index . 0 }}
{{- $template := index . 1 }}
selector:
  matchExpressions:
  - key: elcicd.io/selector
    operator: Exists
  {{- if ($template.selector).matchExpressions }}
    {{- $template.selector.matchExpressions | toYaml | indent 2 }}
  {{- end }}
  matchLabels:
    elcicd.io/selector: {{ include "elcicd-common.elcicdLabels" . }}
  {{- if ($template.selector).matchLabels }}
    {{- $template.selector.matchLabels | toYaml | indent 4 }}
  {{- end }}
{{- end }}

{{/*
Defines the basic structure of a jobTemplate and the keys under it.

  "elcicd-common.metadata"
  [metadata]:
  ---
  "elcicd-kubernetes.jobSpec"
  [spec]:
    [template]:
*/}}
{{- define "elcicd-kubernetes.jobTemplate" }}
{{- $ := index . 0 }}
{{- $jobValues := index . 1 }}

{{- include "elcicd-common.metadata" . }}
{{- include "elcicd-kubernetes.jobSpec" . }}
{{- end }}

{{/*
  ======================================
  elcicd-kubernetes.podTemplate
  ======================================

  PARAMETERS LIST:
    . -> should always be root of chart
    $jobValues -> elCicd template values
  
  ======================================
  
  DEFAULT KEYS
  [spec]:
    [template]:
        activeDeadlineSeconds
        backoffLimit
        completionMode
        completions
        manualSelector
        parallelism
        podFailurePolicy
        restartPolicy -> "Never"
        suspend
        ttlSecondsAfterFinished
        
  "elcicd-kubernetes.podTemplate"
  [spec]:
    [template]:
      [spec]:
      
Defines the spec.template portion of a Job or JobTemplate (CronJob).

  
*/}}
{{- define "elcicd-kubernetes.jobSpec" }}
{{- $ := index . 0 }}
{{- $jobValues := index . 1 }}
spec:
  {{- $whiteList := list "activeDeadlineSeconds"
                         "backoffLimit"
                         "completionMode"
                         "completions"
                         "manualSelector"
                         "parallelism"
                         "podFailurePolicy"
                         "suspend"
                         "ttlSecondsAfterFinished" }}
  {{- include "elcicd-common.outputToYaml" (list $ $jobValues $whiteList) }}
  template:
    {{- $_ := set $jobValues "restartPolicy" ($jobValues.restartPolicy | default "Never") }}
    {{- include "elcicd-kubernetes.podTemplate" (list $ $jobValues false) | indent 4 }}
{{- end }}

{{/*
  ======================================
  elcicd-kubernetes.podTemplate
  ======================================

  PARAMETERS LIST:
    . -> should always be root of chart
    $podValues -> elCicd template values

  ======================================

  HELPER KEYS
  ---
  containers
  ephemeralContainers
  imagePullSecret
  imagePullSecrets
  initContainers
  securityContext
  useLegacyPodSecurityContextDefault [NOTE: in case of running in older version of k8s]
  
  ======================================
  
  DEFAULT KEYS
    activeDeadlineSeconds
    affinity
    automountServiceAccountToken
    dnsConfig
    dnsPolicy
    enableServiceLinks
    hostAliases
    hostIPC
    hostNetwork
    hostPID
    hostname
    nodeName
    nodeSelector
    os
    overhead
    preemptionPolicy
    priority
    priorityClassName
    readinessGates
    restartPolicy
    runtimeClassName
    schedulerName
    serviceAccount
    serviceAccountName
    setHostnameAsFQDN
    shareProcessNamespace
    subdomain
    terminationGracePeriodSeconds
    tolerations
    topologySpreadConstraints
    volumes
  
  ======================================
    
  Generates a PodTemplate.  Used by CronJobs, Deployments, StatefulSets, Pods, and Jobs.
*/}}
{{- define "elcicd-kubernetes.podTemplate" }}
{{- $ := index . 0 }}
{{- $podValues := index . 1 }}

{{- include "elcicd-common.metadata" . }}
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
                          "topologySpreadConstraints"
                          "volumes" }}
  {{- if or $podValues.containers (not (eq $podValues.templateName "podTemplate")) }}
  containers:
    {{- $containers := prepend ($podValues.containers | default list) $podValues }}
    {{- include "elcicd-kubernetes.containers" (list $ $podValues $containers) | trim | nindent 2 }}
  {{- end }}
  {{- if $podValues.ephemeralContainers }}
  ephemeralContainers:
    {{- include "elcicd-kubernetes.containers" (list $ $podValues.ephemeralContainers false) | trim | nindent 2 }}
  {{- end }}
  {{- $_ := set $podValues "imagePullSecrets" ($podValues.imagePullSecrets | default $.Values.elCicdDefaults.imagePullSecrets) }}
  {{- $_ := set $podValues "imagePullSecret" ($podValues.imagePullSecret | default $.Values.elCicdDefaults.imagePullSecret) }}
  {{- if $podValues.imagePullSecrets }}
  imagePullSecrets: {{ $podValues.imagePullSecrets | toYaml | nindent 2 }}
  {{- else if $podValues.imagePullSecret }}
  imagePullSecrets:
  - name: {{ $podValues.imagePullSecret }}
  {{- else }}
  imagePullSecrets: []
  {{- end }}
  {{- if $podValues.initContainers }}
  initContainers:
    {{- include "elcicd-kubernetes.containers" (list $ $podValues.initContainers false) | trim | nindent 2 }}
  {{- end }}
  {{- if $podValues.securityContext }}
  securityContext: {{ $podValues.securityContext | toYaml | nindent 4 }}
  {{- else }}
  securityContext:
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault
  {{- end }}
  {{- include "elcicd-common.outputToYaml" (list $ $podValues $whiteList) }}
{{- end }}

{{/*
  ======================================
  elcicd-kubernetes.podTemplate
  ======================================

  PARAMETERS LIST:
    . -> should always be root of chart
    $podValues -> elCicd template values
    $containers -> list of container definitions in pod; can render containers, initContainers, ephemeralCotainers, etc.

  ======================================

  HELPER KEYS
  ---
    image -> .Values.elCicdDefaults.image
    imagePullPolicy -> .Values.elCicdDefaults.imagePullPolicy
    limitsCpu
    limitsMemory
    name -> $<OBJ_NAME>
    prometheus.port
    prometheus.protocol
    resources
    securityContext
    projectedVolumes
    usePrometheus
  
  ======================================
  
  DEFAULT KEYS
    args
    command
    env
    envFrom
    lifecycle
    livenessProbe
    readinessProbe
    startupProbe
    stdin
    stdinOnce
    terminationMessagePath
    terminationMessagePolicy
    tty
    volumeDevices
    volumeMounts
    workingDir
  
  ======================================

  el-CICD SUPPORTING TEMPLATES:
    "elcicd-kubernetes.envFrom"
    "elcicd-kubernetes.projectedVolumes"
  
  ======================================
    
  Generates a PodTemplate.  Used by CronJobs, Deployments, StatefulSets, Pods, and Jobs.
*/}}
{{- define "elcicd-kubernetes.containers" }}
{{- $ := index . 0 }}
{{- $podValues := index . 1 }}
{{- $containers := index . 2 }}

{{- $whiteList := list "args"
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
{{- range $index, $containerVals := $containers }}
- {{- if or (eq $index 0) $containerVals.name }}
  name: {{ $containerVals.name | default $containerVals.objName }}
  {{- end }}
  image: {{ $containerVals.image | default $.Values.elCicdDefaults.image }}
  imagePullPolicy: {{ $containerVals.imagePullPolicy | default $.Values.elCicdDefaults.imagePullPolicy }}
  {{- if or $containerVals.ports $containerVals.port $.Values.elCicdDefaults.port $containerVals.usePrometheus }}
  ports:
    {{- if $containerVals.ports }}
      {{- $containerVals.ports | toYaml | nindent 2 }}
    {{- else if or $containerVals.port $.Values.elCicdDefaults.port }}
  - name: default-port
    containerPort: {{ $containerVals.containerPort | default $containerVals.targetPort | default $containerVals.port | default $.Values.elCicdDefaults.port }}
    protocol: {{ $containerVals.protocol | default $.Values.elCicdDefaults.protocol }}
    {{- end }}
    {{- if or ($containerVals.prometheus).port (and $containerVals.usePrometheus $.Values.elCicdDefaults.prometheusPort) }}
  - name: prometheus-port
    containerPort: {{ ($containerVals.prometheus).port | default $.Values.elCicdDefaults.prometheusPort }}
    protocol: {{ ($containerVals.prometheus).protocol | default ($.Values.elCicdDefaults.prometheusProtocol | default $.Values.elCicdDefaults.protocol) }}
    {{- end }}
  {{- end }}
  resources:
    limits:
      {{- if ($containerVals.resources).limits }}
        {{- range $limit, $value := ($containerVals.resources).limits }}
      {{ $limit }}: {{ $value }}
        {{- end }}
      {{- else if or $containerVals.limitsCpu $containerVals.limitsMemory }}
        {{- if $containerVals.limitsCpu }}
      cpu: {{ $containerVals.limitsCpu }}
        {{- end }}
        {{- if $containerVals.limitsMemory }}
      memory: {{ $containerVals.limitsMemory }}
        {{- end }}
      {{- else }}
        {{- print " {}" }}
      {{- end }}
    requests:
      {{- if ($containerVals.resources).requests }}
        {{- range $request, $value := ($containerVals.resources).requests }}
      {{ $request }}: {{ $value }}
        {{- end }}
      {{- else if or $containerVals.requestsCpu $containerVals.requestsMemory }}
        {{- if $containerVals.requestsCpu }}
      cpu: {{ $containerVals.requestsCpu }}
        {{- end }}
        {{- if $containerVals.requestsMemory }}
      memory: {{ $containerVals.requestsMemory }}
        {{- end }}
      {{- else }}
        {{- print " {}" }}
      {{- end }}
  {{- if $containerVals.containerSecurityContext }}
  securityContext: {{ $containerVals.containerSecurityContext | toYaml | nindent 4 }}
  {{- else }}
  securityContext:
    allowPrivilegeEscalation: false
    capabilities:
      drop:
      - ALL
  {{- end }}
  {{- if $containerVals.projectedVolumes }}
    {{- include "elcicd-kubernetes.projectedVolumes" (list $ $podValues $containerVals) }}
  {{- end }}
  {{- include "elcicd-common.outputToYaml" (list $ $containerVals $whiteList) }}
{{- end }}
{{- end }}