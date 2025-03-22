
{{/*
  ======================================
  elcicd-renderer.gatherElCicdTemplates
  ======================================

  PARAMETERS LIST:
    $ -> root of chart
    $template -> an el-Cicd copyResource template

  ======================================

  el-CICD TEMPLATE KEYS:
    ignoreLabels -> do not copy source resource labels when copying
    labels -> add/overwrite labels on source resource with given labels
    ignoreAnnotations -> do not copy source resource annotations when copying
    annotations -> add/overwrite annotations on source resource with given labels
    

  ======================================

  Looks up the specified resource in the fromNamespace by kind and metadata.name, copies it,
  and then deploys it to the toNamespace.  If the resource cannot be found, it will check 
  .Values.templateCommandRunning and $template.optional.  If either is true, it will simply log
  the resource cannot be found; otherwise, the chart will be failed.
*/}}
{{- define "elcicd-renderer.copyResource" }}
  {{- $ := get . "$" }}
  {{- $template := .elCicdTemplate }}
  
  {{- $resource := (lookup ($template.apiVersion | default "v1") 
                            $template.kind 
                            $template.fromNamespace
                            ($template.srcMetadataName | default $template.objName)) }}
                            
  {{- if $resource }}
    {{- $newResource := dict }}
    {{- $_ := set $newResource  "apiVersion" $resource.apiVersion }}
    {{- $_ := set $newResource  "kind" $resource.kind }}
    {{- $_ := set $newResource  "metadata" dict }}
    {{- $_ := set $newResource.metadata  "name" $resource.metadata.name }}
    {{- $_ := set $newResource.metadata  "namespace" $template.toNamespace }}
    
    {{- if and (not $template.ignoreLabels) $resource.metadata.labels }}
      {{- $_ := set $newResource.metadata  "labels" (deepCopy $resource.metadata.labels) }}
    {{- end }}
    
    {{- if $template.labels }}
      {{- $labels := ($newResource.metadata.labels | default dict) }}
      {{- $_ := set $newResource.metadata "labels" (mergeOverwrite $labels $template.labels) }}
    {{- end }}
    
    {{- if and (not $template.ignoreAnnotations) $resource.metadata.annotations }}
      {{- $_ := set $newResource.metadata  "annotations" (deepCopy $resource.metadata.annotations) }}
    {{- end }}
    
    {{- if $template.annotations }}
      {{- $annotations := ($newResource.metadata.annotations | default dict) }}
      {{- $_ := set $newResource.metadata "annotations" (mergeOverwrite $annotations  $template.annotations) }}
    {{- end }}
    
    {{- if $resource.spec }}
      {{- $_ := set $newResource "spec" (deepCopy $resource.spec) }}
    {{- end }}
    
    {{- if $resource.data }}
      {{- $_ := set $newResource "data" (deepCopy $resource.data) }}
    {{- end }}
    
    {{- if $resource.dataBinary }}
      {{- $_ := set $newResource "dataBinary" (deepCopy $resource.dataBinary) }}
    {{- end }}
    
    {{- if $resource.type }}
      {{- $_ := set $newResource "type" $resource.type }}
    {{- end }}

    {{- $newResource | toYaml }}
  {{- else if and (not $.Values.templateCommandRunning) (not $template.optional) }}
    {{- fail (printf "Cannot find %s %s in namespace %s" $template.kind $template.objName $template.fromNamespace) }}
  {{- else }}
# WARNING: {{ printf "Cannot find %s %s in namespace %s" $template.kind $template.objName $template.fromNamespace }}
  {{- end }}
{{- end }}