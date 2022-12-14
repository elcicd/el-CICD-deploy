{{/*
ConfigMap
*/}}
{{- define "elCicdResources.configMap" }}
{{- $ := index . 0 }}
{{- $cmValues := index . 1 }}
{{- $_ := set $cmValues "kind" "ConfigMap" }}
{{- $_ := set $cmValues "apiVersion" "v1" }}
{{- include "elCicdResources.apiObjectHeader" . }}
{{- if $cmValues.binaryData }}
binaryData: {{ $cmValues.binaryData | toYaml | nindent 2}}
{{- end }}
{{- if $cmValues.data }}
data: {{ $cmValues.data | toYaml | nindent 2}}
{{- end }}
{{- if $cmValues.immutable }}
immutable: {{ $cmValues.immutable }}
{{- end }}
{{- end }}

{{/*
Secret
*/}}
{{- define "elCicdResources.secret" }}
{{- $ := index . 0 }}
{{- $secretValues := index . 1 }}
{{- $_ := set $secretValues "kind" "Secret" }}
{{- $_ := set $secretValues "apiVersion" "v1" }}
{{- include "elCicdResources.apiObjectHeader" . }}
{{- if $secretValues.data }}
data: {{ $secretValues.data | toYaml | nindent 2}}
{{- end }}
{{- if $secretValues.stringData }}
stringData: {{ $secretValues.stringData | toYaml | nindent 2}}
{{- end }}
{{- if $secretValues.immutable }}
immutable: {{ $secretValues.immutable }}
{{- end }}
{{- end }}

{{/*
Image Registry Secret
*/}}
{{- define "elCicdResources.docker-registry-secret" }}
{{- $ := index . 0 }}
{{- $secretValues := index . 1 }}
{{- $_ := set $secretValues "kind" "Secret" }}
{{- $_ := set $secretValues "apiVersion" "v1" }}
{{- include "elCicdResources.apiObjectHeader" . }}
data:
  {{- if $secretValues.usernamePassword }}
    {{- $_ := set $secretValues "usernamePassword" (regexSplit ":" (trim $secretValues.usernamePassword) -1) }}
    {{- $_ := set $secretValues "username" (index $secretValues.usernamePassword 0) }}
    {{- $_ := set $secretValues "password" (index $secretValues.usernamePassword 1) }}
  {{- end }}

  {{- $dockerconfigjson := "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\",\"auth\":\"%s\"}}}" }}
  {{- $base64Auths := (printf "%s:%s" $secretValues.username $secretValues.password | b64enc) }}
  .dockerconfigjson: {{ printf $dockerconfigjson $secretValues.server $secretValues.username $secretValues.password $base64Auths | b64enc }}
{{- if $secretValues.immutable }}
immutable: {{ $secretValues.immutable }}
{{- end }}
type: kubernetes.io/dockerconfigjson
{{- end }}

{{/*
PersistentVolume
*/}}
{{- define "elCicdResources.persistentVolume" }}
{{- $ := index . 0 }}
{{- $pvValues := index . 1 }}
{{- $_ := set $pvValues "kind" "PersistentVolume" }}
{{- $_ := set $pvValues "apiVersion" "v1" }}
{{- include "elCicdResources.apiObjectHeader" . }}
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
                         "storageos	"
                         "vsphereVolume"
                         "volumeMode"	}}
  {{- include "elCicdResources.outputToYaml" (list $ $pvValues $whiteList) }}
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
PersistentVolumeClaim
*/}}
{{- define "elCicdResources.persistentVolumeClaim" }}
{{- $ := index . 0 }}
{{- $pvcValues := index . 1 }}
{{- $_ := set $pvcValues "kind" "PersistentVolumeClaim" }}
{{- $_ := set $pvcValues "apiVersion" "v1" }}
{{- include "elCicdResources.apiObjectHeader" . }}
spec:
  {{- $whiteList := list "dataSource"
                         "dataSourceRef"
                         "selector"
                         "storageClassName"
                         "volumeMode"
                         "volumeName"	}}
  {{- include "elCicdResources.outputToYaml" (list $ $pvcValues $whiteList) }}
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

