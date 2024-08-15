{{/*
  The following templates add projected volumes in two ways.  The first, more static way is a straight defintion of 
  a projected volume list per type; e.g. configMap, secret, serviceAccountToken, etc.  In this case, both the volume and
  the volumeMount on the default container is defined.
  
  The second, non-standard means of generated projected volumes and volumeMounts only applies to ConfigMaps and/or Secrets.
  Three helper keys available to the user under the projectedVolumes key are configMapsByLabels, secretsByLabel, and labels (which
  does not differentiate between Secrets or ConfigMaps), and adds either configMaps and/or secrets to the list of resources of a 
  projected volume after lookup by their labels.  Resource labels are only checked whether a label in list is defined for the resource,
  and does not confirm a value.
  
    projectedVolumes:
    - name
      mountPath
      configMaps:
        <configMap.metadata.name>:
          items: {} # optional, will import all data to files if missing
      secrets:
      - <secret.metadata.name>:
          items: {} # optional, will import all data to files if missing
      <other projected volume types>:
        <other projected volume keys>
      configMapsByLabels:
      - <labelKey>
      secretMapLabels:
      - <labelKey>
      labels:
      - <labelKey>
      
  Produces:
  
    containers:
      volumeMounts:
      - name
        mountPath
    volumes:
    - name
      projected
      - configMap
      - secret
      - etc.
*/}}

{{- define "elcicd-kubernetes.projectedVolumes" }}
  {{- $ := index . 0 }}
  {{- $podValues := index . 1 }}
  {{- $containerVals := index . 2 }}
  
  {{- $volumeMounts := dict }}
  {{- range $projectedVolume := $containerVals.projectedVolumes }}
    {{- include "elcicd-kubernetes.addConfigMapsAndSecretsByLabels" (list $ $podValues $projectedVolume) }}

    {{- include "elcicd-kubernetes.createProjectedVolume" (list $ $podValues $projectedVolume) }}

    {{- $mountedVolume := dict "mountPath" $projectedVolume.mountPath }}
    {{- $_ := set $mountedVolume "name" $projectedVolume.name }}
    {{- if $projectedVolume.mountPropagation }}
      {{- $_ := set $mountedVolume "mountPropagation" $projectedVolume.mountPropagation }}
    {{- end }}
    {{- $_ := set $mountedVolume "readOnly" ($projectedVolume.readOnly | default false) }}
    {{- if $projectedVolume.subPath }}
      {{- $_ := set $mountedVolume "subPath" $projectedVolume.subPath }}
    {{- end }}
    {{- if $projectedVolume.subPathExpr }}
      {{- $_ := set $mountedVolume "subPathExpr" $projectedVolume.subPathExpr }}
    {{- end }}
    {{- $_ := set $volumeMounts $projectedVolume.name $mountedVolume }}
  {{- end }}
  {{- $_ := set $containerVals "volumeMounts" (concat ($containerVals.volumeMounts | default list) (values $volumeMounts)) }}
{{- end }}

{{- define "elcicd-kubernetes.createProjectedVolume" }}
  {{- $ := index . 0 }}
  {{- $podValues := index . 1 }}
  {{- $projectedVolume := index . 2 }}

  {{- $volume := dict }}
  {{- $_ := set $volume "name" $projectedVolume.name }}
  {{- if $projectedVolume.defaultMode }}
    {{- $_ := set $volume "defaultMode" $projectedVolume.defaultMode }}
  {{- end }}
  {{- $_ := set $volume "projected" dict }}
  {{- $_ := set $volume.projected "sources" list }}
  
  {{- $cmSources := dict }}
  {{- range $configMapName, $volumeDef := $projectedVolume.configMaps }}
    {{- $_ := set $volumeDef "name" $configMapName}}
    {{- $_ := set $cmSources $configMapName (dict "configMap" $volumeDef) }}
  {{- end }}
  
  {{- $secSources := dict }}
  {{- range $secretName, $volumeDef := $projectedVolume.secrets }}
    {{- $_ := set $volumeDef "name" $secretName}}
    {{- $_ := set $secSources $secretName (dict "secret" $volumeDef) }}
  {{- end }}
  
  {{- $saTokenSources := dict }}
  {{- range $saToken := $projectedVolume.serviceAccountTokens }}
    {{- $_ := set $secSources $saToken.name (dict "serviceAccountToken" $saToken) }}
  {{- end }}
  
  {{- $dApiSources := dict }}
  {{- range $dApiToken := $projectedVolume.downwardAPIs }}
    {{- $_ := set $secSources $dApiSources.name (dict "downwardAPI" $dApiToken) }}
  {{- end }}

  {{- $volumeSources := concat (values $cmSources) (values $secSources) (values $saTokenSources) (values $dApiSources) }}
  {{- if and (not $volumeSources) (not $.Values.renderValuesForKust) }}
    {{- fail (printf "no projected sources found for %s" $projectedVolume.name) }}
  {{- end }}
  {{- $_ := set $volume.projected "sources" $volumeSources }}
  {{- $_ := set $podValues "volumes" (append ($podValues.volumes | default list) $volume) }}
{{- end }}

{{- define "elcicd-kubernetes.addConfigMapsAndSecretsByLabels" }}
  {{- $ = index . 0 }}
  {{- $podValues := index . 1 }}
  {{- $projectedVolume := index . 2 }}
  
  {{- $resultKey := uuidv4 }}

  {{- if or $projectedVolume.configMapsByLabels $projectedVolume.labels }}
    {{- $resources := ((lookup "v1" "ConfigMap" $podValues.namespace "").items | default list) }}
    {{- $resourceLabels := merge ($projectedVolume.configMapsByLabels | default dict) ($projectedVolume.labels | default dict) }}
    {{- include  "elcicd-kubernetes.getResourcesByLabel" (list $ $resources $resourceLabels $resultKey) }}
    {{- $_ := set $projectedVolume "configMaps" (merge ($projectedVolume.configMaps | default dict) (get $.Values.__EC_RESULT_DICT $resultKey)) }}
  {{- end }}
  
  {{- if or $projectedVolume.secretsByLabels $projectedVolume.labels }}
    {{- $resources := concat $resources ((lookup "v1" "Secret" $podValues.namespace "").items | default list) }}
    {{- $resourceLabels := merge ($projectedVolume.secretsByLabel | default dict) ($projectedVolume.labels | default dict) }}
    {{- include  "elcicd-kubernetes.getResourcesByLabel" (list $ $resources $resourceLabels $resultKey) }}
    {{- $_ := set $projectedVolume "secrets" (merge ($projectedVolume.secrets | default dict) (get $.Values.__EC_RESULT_DICT $resultKey)) }}
  {{- end }}

  {{- $_ := unset $.Values.__EC_RESULT_DICT $resultKey }}
{{- end }}

{{- define "elcicd-kubernetes.getResourcesByLabel" }}
  {{- $ = index . 0 }}
  {{- $resources := index . 1 }}
  {{- $resourceLabels := index . 2 }}
  {{- $resultKey := index . 3 }}

  {{- $labelResources := dict }}
  {{- range $resourceLabel, $resourceVolDef := $resourceLabels }}
    {{- $value := get $resourceVolDef "value" }}
    {{- $resourceVolDef = unset $resourceVolDef "value" }}
    {{- range $resource := $resources }}
      {{- if $resource.metadata.labels  }}
        {{- if hasKey $resource.metadata.labels $resourceLabel }}
          {{- if or (not $value) (eq $value (get $resource.metadata.labels $resourceLabel)) }}
            {{- $_ := set $labelResources $resource.metadata.name (deepCopy $resourceVolDef) }}
          {{- end }}
        {{- end }}
      {{- end }}
    {{- end }}
  {{- end }}
  
  {{- $_ := set $.Values.__EC_RESULT_DICT $resultKey $labelResources }}
{{- end }}