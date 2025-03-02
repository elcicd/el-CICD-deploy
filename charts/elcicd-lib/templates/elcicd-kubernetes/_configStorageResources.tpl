{{/*
  Defines templates for rendering Kubernetes workload resources, including:
  - ConfigMap
  - Secret
    - Image Registry (Docker) Secret
    - Service Account Token Secret
  - PersistentVolume
  - PersistentVolumeClaim

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
  elcicd-kubernetes.configMap
  ======================================

  PARAMETERS LIST:
    . -> should always be root of chart
    $cmValues -> elCicd template for ConfigMap

  ======================================

  DEFAULT KEYS
  ---
    binaryData
    data
    immutable

  ======================================

  el-CICD SUPPORTING TEMPLATES:
    "elcicd-common.apiObjectHeader"

  ======================================

  Defines a el-CICD template for a Kubernetes ConfigMap.
*/}}
{{- define "elcicd-kubernetes.configMap" }}
{{- $args := . }}
{{- $ := get $args "$" }}
{{- $cmValues := get $args "elCicdTemplate" }}

{{- $_ := set $cmValues "kind" "ConfigMap" }}
{{- include "elcicd-common.apiObjectHeader" . }}
{{- $whiteList := list "binaryData"
                       "data"
                       "immutable"	}}
{{- include "elcicd-common.outputToYaml" (list $ $cmValues $whiteList 0) }}
{{- end }}

{{/*
  ======================================
  elcicd-kubernetes.secret
  ======================================

  PARAMETERS LIST:
    . -> should always be root of chart
    $secretValues -> elCicd template for Secret

  ======================================

  HELPER KEYS
  --
  {{ if $secretValues.type == "dockerconfigjson" }}
  [data]:
    [.dockercfgjson]:
  [stringData]:
    username:
    password:
  --
  {{ if $secretValues.type == "service-account-token" }}
  [metadata]:
    [annotations]:
      [kubernetes.io/service-account.name]: $secretValues.serviceAccount
  [stringData]:
    username:
    password:

  ======================================

  DEFAULT KEYS
  ---
    [spec]:
      data
      immutable
      stringData
      type

  ======================================

  el-CICD SUPPORTING TEMPLATES:
    "elcicd-common.apiObjectHeader"

  ======================================

  Defines a el-CICD template for a Kubernetes Secret.
*/}}
{{- define "elcicd-kubernetes.secret" }}
{{- $args := . }}
{{- $ := get $args "$" }}
{{- $secretValues := get $args "elCicdTemplate" }}

{{- $_ := set $secretValues "kind" "Secret" }}
{{- if eq ($secretValues.type | default "") "dockerconfigjson" }}
  {{- $_ := set  $secretValues "type" "kubernetes.io/dockerconfigjson" }}
  {{- $dockerconfigjson := "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\",\"auth\":\"%s\"}}}" }}
  {{- $base64Auths := (printf "%s:%s" $secretValues.username $secretValues.password | b64enc) }}
  {{- $dockerconfigjson = (printf $dockerconfigjson $secretValues.server $secretValues.username $secretValues.password $base64Auths | b64enc) }}

  {{- $_ := set  $secretValues "data"  ($secretValues.data | default dict) }}
  {{- $_ := set  $secretValues.data ".dockerconfigjson" $dockerconfigjson }}

  {{- $_ := set  $secretValues "stringData" ($secretValues.stringData | default dict) }}
  {{- $_ := set  $secretValues.stringData "username" $secretValues.username }}
  {{- $_ := set  $secretValues.stringData "password" $secretValues.password }}
{{- else if and (eq ($secretValues.type | default "") "service-account-token") $secretValues.serviceAccount }}
  {{- $_ := set  $secretValues "type" "kubernetes.io/service-account-token" }}
  {{- $_ := set  $secretValues "annotations"  ($secretValues.annotations | default dict) }}
  {{- $_ := set  $secretValues.annotations "kubernetes.io/service-account.name" $secretValues.serviceAccount }}
{{- end }}
{{- include "elcicd-common.apiObjectHeader" . }}
{{- $whiteList := list "data"
                       "immutable"
                       "stringData"
                       "type"	}}
{{- include "elcicd-common.outputToYaml" (list $ $secretValues $whiteList 0) }}
{{- end }}

{{/*
  ======================================
  elcicd-kubernetes.persistentVolume
  ======================================

  PARAMETERS LIST:
    . -> should always be root of chart
    $pvValues -> elCicd template for PersistentVolume

  ======================================

  HELPER KEYS
  ---
  [spec]:
    [accessMode]:
      accessModes
  ---
  [spec]:
    [accessMode]:
    - accessMode
  ---
  [spec]:
    [capacity]:
      [storage]: $pvValues.storageCapacity

  ======================================

  DEFAULT KEYS
  ---
    [spec]:
      awsElasticBlockStore
      azureDisk
      azureFile
      cephfs
      cinder
      claimRef
      csi
      fc
      flexVolume
      flocker
      gcePersistentDisk
      glusterfs
      hostPath
      iscsi
      local
      mountOptions
      nfs
      nodeAffinity
      persistentVolumeReclaimPolicy
      portworxVolume
      quobyte
      rbd
      scaleIO
      storageClassName
      storageos
      vsphereVolume
      volumeMode

  ======================================

  el-CICD SUPPORTING TEMPLATES:
    "elcicd-common.apiObjectHeader"

  ======================================

  Defines a el-CICD template for a Kubernetes PersistentVolume.
*/}}
{{- define "elcicd-kubernetes.persistentVolume" }}
  {{- $args := . }}
  {{- $ := get $args "$" }}
  {{- $pvValues := get $args "elCicdTemplate" }}

{{- $_ := set $pvValues "kind" "PersistentVolume" }}
{{- include "elcicd-common.apiObjectHeader" . }}
spec:
  {{- $whiteList := list "awsElasticBlockStore"
                         "azureDisk"
                         "azureFile"
                         "cephfs"
                         "cinder"
                         "claimRef"
                         "csi"
                         "fc"
                         "flexVolume"
                         "flocker"
                         "gcePersistentDisk"
                         "glusterfs"
                         "hostPath"
                         "iscsi"
                         "local"
                         "mountOptions"
                         "nfs"
                         "nodeAffinity"
                         "persistentVolumeReclaimPolicy"
                         "portworxVolume"
                         "quobyte"
                         "rbd"
                         "scaleIO"
                         "storageClassName"
                         "storageos"
                         "vsphereVolume"
                         "volumeMode"	}}
  {{- include "elcicd-common.outputToYaml" (list $ $pvValues $whiteList) }}
  accessModes:
  {{- if $pvValues.accessModes }}
  {{ $pvValues.accessModes | toYaml }}
  {{- else }}
  - {{ $pvValues.accessMode }}
  {{- end }}
  capacity:
    storage: {{ required "PV's must specify storageCapacity" $pvValues.storageCapacity }}
{{- end }}


{{/*
  ======================================
  elcicd-kubernetes.persistentVolumeClaim
  ======================================

  PARAMETERS LIST:
    . -> should always be root of chart
    $pvcValues -> elCicd template for PersistentVolumeClaim

  ======================================

  HELPER KEYS
  ---
  [spec]:
    [accessMode]:
      accessModes
  ---
  [spec]:
    [accessMode]:
    - accessMode
  ---
  [spec]:
    [resources]:
      [requests]: $pvcValues.storageRequest
      [limits]: $pvcValues.storageLimit

  ======================================

  DEFAULT KEYS
  ---
    [spec]:
      dataSource
      dataSourceRef
      selector
      storageClassName
      volumeMode
      volumeName

  ======================================

  el-CICD SUPPORTING TEMPLATES:
    "elcicd-common.apiObjectHeader"

  ======================================

  Defines a el-CICD template for a Kubernetes PersistentVolumeClaim.
*/}}
{{- define "elcicd-kubernetes.persistentVolumeClaim" }}
{{- $args := . }}
{{- $ := get $args "$" }}
{{- $pvcValues := get $args "elCicdTemplate" }}

{{- $_ := set $pvcValues "kind" "PersistentVolumeClaim" }}
{{- include "elcicd-common.apiObjectHeader" . }}
spec:
  {{- $whiteList := list "dataSource"
                         "dataSourceRef"
                         "selector"
                         "storageClassName"
                         "volumeMode"
                         "volumeName"	}}
  {{- include "elcicd-common.outputToYaml" (list $ $pvcValues $whiteList) }}
  accessModes:
  {{- if $pvcValues.accessModes }}
  {{ $pvcValues.accessModes | toYaml | indent 2 }}
  {{- else }}
  - {{ $pvcValues.accessMode }}
  {{- end }}
  resources:
  {{- if $pvcValues.resources }}
    {{- $pvcValues.resources | toYaml | nindent 4 }}
  {{- else }}
    requests:
      storage: {{ required "PVC's must set storageLimit or fully define resources" $pvcValues.storageRequest }}
    {{- if $pvcValues.storageLimit }}
    limits:
      storage: {{ $pvcValues.storageLimit }}
    {{- end }}
  {{- end }}
{{- end }}

