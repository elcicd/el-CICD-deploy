{{/*
  Defines templates for rendering Kubernetes workload resources, including:
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
  ======================================
  elcicd-kubernetes.cronjob
  ======================================

  PARAMETERS LIST:
    . -> should always be root of chart
    $cjValues -> elCicd template

  ======================================

  DEFAULT KEYS
    [spec]:
      concurrencyPolicy
      failedJobsHistoryLimit
      schedule
      startingDeadlineSeconds
      successfulJobsHistoryLimit
      parallelism
      ttlSecondsAfterFinished

  ======================================

  el-CICD SUPPORTING TEMPLATES:
    "elcicd-common.apiObjectHeader"
    spec:
      jobTemplate:
        "elcicd-kubernetes.jobTemplate"

  ======================================

  Defines a el-CICD template for a Kubernetes CronJob.
*/}}
{{- define "elcicd-kubernetes.cronjob" }}
  {{- $ := get . "$" }}
  {{- $cjValues := .elCicdTemplate }}

  {{- $_ := set $cjValues "kind" "CronJob" }}
  {{- $_ := set $cjValues "apiVersion" ($cjValues.apiVersion | default "batch/v1") }}
  {{- include "elcicd-common.apiObjectHeader" . }}
spec:
  {{- $whiteList := list "concurrencyPolicy"
                         "failedJobsHistoryLimit"
                         "parallelism"
                         "schedule"
                         "startingDeadlineSeconds"
                         "successfulJobsHistoryLimit"
                         "ttlSecondsAfterFinished" }}
  {{- include "elcicd-common.outputToYaml" (dict "$" $ "elCicdTemplate" $cjValues "whiteList" $whiteList) }}
  jobTemplate: {{ include "elcicd-kubernetes.jobTemplate" . | indent 4 }}
{{- end }}

{{/*
  ======================================
  elcicd-kubernetes.deployment
  ======================================

  PARAMETERS LIST:
    . -> should always be root of chart
    $deployValues -> elCicd template for Deployment

  ======================================

  HELPER KEYS
  ---
  [spec]:
    revisionHistoryLimit -> .Values.elCicdDefaults.deploymentRevisionHistoryLimit
  ---
  [spec]:
    [strategy]:
      [type]: strategyType
      [rollingUpdate { if $deployValues.strategyType == "RollingUpdate" } ]:
        rollingUpdateMaxSurge -> .Values.elCicdDefaults.rollingUpdateMaxSurge
        rollingUpdateMaxUnavailable -> .Values.elCicdDefaults.rollingUpdateMaxUnavailable

  ======================================

  DEFAULT KEYS
  ---
    [spec]:
      minReadySeconds
      progressDeadlineSeconds
      replicas

  ======================================

  el-CICD SUPPORTING TEMPLATES:
    "elcicd-common.apiObjectHeader"
    spec:
      template:
        "elcicd-kubernetes.podTemplate"

  ======================================

  Defines a el-CICD template for a Kubernetes Deployment.
*/}}
{{- define "elcicd-kubernetes.deployment" }}
  {{- $ := get . "$" }}
  {{- $deployValues := .elCicdTemplate }}

  {{- $_ := set $deployValues "kind" "Deployment" }}
  {{- $_ := set $deployValues "apiVersion" ($deployValues.apiVersion | default "apps/v1") }}
  {{- include "elcicd-common.apiObjectHeader" . }}
spec:
  {{- $whiteList := list "minReadySeconds"
                         "progressDeadlineSeconds"
                         "replicas" }}
  {{- include "elcicd-common.outputToYaml" (dict "$" $ "elCicdTemplate" $deployValues "whiteList" $whiteList) }}
  revisionHistoryLimit: {{ ($deployValues.revisionHistoryLimit | default $.Values.elCicdDefaults.deploymentRevisionHistoryLimit) | int }}
  {{- include "elcicd-kubernetes.labelSelector" . | indent 2 }}
  {{- if $deployValues.strategyType }}
  strategy:
    {{- if (eq $deployValues.strategyType "RollingUpdate") }}
    rollingUpdate:
      maxSurge: {{ $deployValues.rollingUpdateMaxSurge | default $.Values.elCicdDefaults.rollingUpdateMaxSurge }}
      maxUnavailable: {{ $deployValues.rollingUpdateMaxUnavailable | default $.Values.elCicdDefaults.rollingUpdateMaxUnavailable }}
    {{- end }}
    type: {{ $deployValues.strategyType }}
  {{- end }}
  {{- $args := dict "$" $ "elCicdTemplate" $deployValues }}
  template: {{ include "elcicd-kubernetes.podTemplate" $args | indent 4 }}
{{- end }}

{{/*
  ======================================
  elcicd-kubernetes.horizontalPodAutoscaler
  ======================================

  PARAMETERS LIST:
    . -> should always be root of chart
    $hpaValues -> elCicd template for HorizontalPodAutoscaler

  ======================================

  DEFAULT KEYS
  ---
    [spec]:
      behavior
      maxReplicas
      minReplicas
      scaleTargetRef
        apiVersion -> / "apps/v1"
        kind -> / "Deployment"
        name -> / $<OBJ_NAME>
    ---
    [spec]:
      [metrics]:
      - type:
        [<type>]:
          container
          describedObject
          name
          metric
          target

  ======================================

  el-CICD SUPPORTING TEMPLATES
  ---
    "elcicd-common.apiObjectHeader"

  ======================================

  Defines a el-CICD template for a Kubernetes HorizontalPodAutoscaler.

  Defining hpa metrics in the el-CICD template:

    metrics:
    - type: <type>
      name: <name>
      target:
        <target def per hpa>

  Will generate in the final YAML:

  spec:
    metrics:
    - type: <Type> # note the title case
      <type>:
        name: <name>
        target:
          <target def per hpa>

  The el-CICD template only require defining hpa the type, and el-CICD template will generate the correct
  YAML structure.
*/}}
{{- define "elcicd-kubernetes.horizontalPodAutoscaler" }}
  {{- $ := get . "$" }}
  {{- $hpaValues := .elCicdTemplate }}

  {{- $_ := set $hpaValues "kind" "HorizontalPodAutoscaler" }}
  {{- $_ := set $hpaValues "apiVersion" ($hpaValues.apiVersion | default "autoscaling/v2") }}
  {{- include "elcicd-common.apiObjectHeader" . }}
spec:
  {{- $whiteList := list "behavior"
                         "maxReplicas"
                         "metrics"
                         "minReplicas" }}
  {{- include "elcicd-common.outputToYaml" (dict "$" $ "elCicdTemplate" $hpaValues "whiteList" $whiteList) }}
  scaleTargetRef:
    apiVersion: {{ ($hpaValues.scaleTargetRef).apiVersion | default "apps/v1"  }}
    kind: {{ ($hpaValues.scaleTargetRef).kind | default "Deployment" }}
    name: {{ ($hpaValues.scaleTargetRef).name | default $hpaValues.objName }}
{{- end }}

{{/*
  ======================================
  elcicd-kubernetes.job
  ======================================

  PARAMETERS LIST:
    . -> should always be root of chart
    $jobValues -> elCicd template for Job

  ======================================

  el-CICD SUPPORTING TEMPLATES
  ---
    "elcicd-common.apiObjectHeader"
    "elcicd-kubernetes.jobSpec"

  ======================================

  Defines a el-CICD template for a Kubernetes Job.
*/}}
{{- define "elcicd-kubernetes.job" }}
  {{- $ := get . "$" }}
  {{- $jobValues := .elCicdTemplate }}

  {{- $_ := set $jobValues "kind" "Job" }}
  {{- $_ := set $jobValues "apiVersion" ($jobValues.apiVersion | default "batch/v1") }}
  {{- include "elcicd-common.apiObjectHeader" . }}
  {{- include "elcicd-kubernetes.jobSpec" . }}
{{- end }}

{{/*
  ======================================
  elcicd-kubernetes.pod
  ======================================

  PARAMETERS LIST:
    . -> should always be root of chart
    $podValues -> elCicd template for Pod

  ======================================

  el-CICD SUPPORTING TEMPLATES
  ---
    "elcicd-common.apiObjectHeader"
    "elcicd-kubernetes.podTemplate"

  ======================================

  Defines a el-CICD template for a Kubernetes Pod.
*/}}
{{- define "elcicd-kubernetes.pod" }}
  {{- $ := get . "$" }}
  {{- $podValues := .elCicdTemplate }}

  {{- $_ := set $podValues "kind" "Pod" }}
  {{- include "elcicd-common.apiObjectHeader" . }}
  {{- include "elcicd-kubernetes.podTemplate" . }}
{{- end }}

{{/*
  ======================================
  elcicd-kubernetes.statefulset
  ======================================

  PARAMETERS LIST:
    . -> should always be root of chart
    $deployValues -> elCicd template for StatefulSet

  ======================================

  DEFAULT KEYS:
  ---
   [spec]:
      minReadySeconds
      ordinals
      persistentVolumeClaimRetentionPolicy
      podManagementPolicy
      replicas
      revisionHistoryLimit
      updateStrategy
      volumeClaimTemplates

  ======================================

  el-CICD SUPPORTING TEMPLATES
  ---
    "elcicd-common.apiObjectHeader"
    spec:
      "elcicd-kubernetes.labelSelector"
      template:
        "elcicd-kubernetes.podTemplate"

  ======================================

  Defines a el-CICD template for a Kubernetes StatefulSet.
*/}}
{{- define "elcicd-kubernetes.statefulset" }}
  {{- $ := get . "$" }}
  {{- $stsValues := .elCicdTemplate }}

  {{- $_ := set $stsValues "kind" "StatefulSet" }}
  {{- $_ := set $stsValues "apiVersion" ($stsValues.apiVersion | default "apps/v1") }}
  {{- include "elcicd-common.apiObjectHeader" . }}
spec:
  {{- $whiteList := list "minReadySeconds"
                         "ordinals"
                         "persistentVolumeClaimRetentionPolicy"
                         "podManagementPolicy"
                         "replicas"
                         "revisionHistoryLimit"
                         "updateStrategy"
                         "volumeClaimTemplates" }}
  {{- include "elcicd-common.outputToYaml" (dict "$" $ "elCicdTemplate" $stsValues "whiteList" $whiteList) }}
  {{- include "elcicd-kubernetes.labelSelector" . | indent 2 }}
  template:
  {{- $args := dict "$" $ "elCicdTemplate" $stsValues }}
  {{- include "elcicd-kubernetes.podTemplate" $args | indent 4 }}
{{- end }}


{{/*
  ======================================
  elcicd-kubernetes.daemonset
  ======================================

  PARAMETERS LIST:
    . -> should always be root of chart
    $deployValues -> elCicd template for DaemonSet

  ======================================

  DEFAULT KEYS:
  ---
   [spec]:
      minReadySeconds
      revisionHistoryLimit
      updateStrategy

  ======================================

  el-CICD SUPPORTING TEMPLATES
  ---
    "elcicd-common.apiObjectHeader"
    spec:
      "elcicd-kubernetes.labelSelector"
      template:
        "elcicd-kubernetes.podTemplate"

  ======================================

  Defines a el-CICD template for a Kubernetes DaemonSet.
*/}}
{{- define "elcicd-kubernetes.daemonset" }}
  {{- $ := get . "$" }}
  {{- $dsValues := .elCicdTemplate }}

  {{- $_ := set $dsValues "kind" "DaemonSet" }}
  {{- $_ := set $dsValues "apiVersion" ($dsValues.apiVersion | default "apps/v1") }}
  {{- include "elcicd-common.apiObjectHeader" . }}
spec:
  {{- $whiteList := list "minReadySeconds"
                         "revisionHistoryLimit"
                         "updateStrategy" }}
  {{- include "elcicd-common.outputToYaml" (dict "$" $ "elCicdTemplate" $dsValues "whiteList" $whiteList) }}
  {{- include "elcicd-kubernetes.labelSelector" . | indent 2 }}
  template:
  {{- $args := dict "$" $ "elCicdTemplate" $dsValues }}
  {{- include "elcicd-kubernetes.podTemplate" $args | indent 4 }}
{{- end }}