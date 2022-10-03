{{- define "elCicdChart.mergeProfileDefs" }}
  {{- $ := index . 0 }}
  {{- $profileDefs := index . 1 }}
  {{- $elCicdDefs := index . 2 }}

  {{- $appName := $profileDefs.appName }}

  {{- if $appName }}
    {{- include "elCicdChart.mergeMapInto" (list $ $profileDefs.elCicdDefs $elCicdDefs) }}
  {{- end }}

  {{- range $profile := $.Values.profiles }}
    {{- $profileDefs := get $profileDefs (printf "elCicdDefs-%s" $profile) }}
    {{- include "elCicdChart.mergeMapInto" (list $ $profileDefs $elCicdDefs) }}
  {{- end }}

  {{- if $appName }}
    {{- $appNameDefsKey := printf "elCicdDefs-%s" $appName }}
    {{- $appNameDefs := tuple (deepCopy (get $.Values $appNameDefsKey)) (get $profileDefs $appNameDefsKey ) }}
    {{- range $appNameDefs := $appNameDefs }}
      {{- include "elCicdChart.mergeMapInto" (list $ $appNameDefs $elCicdDefs) }}
    {{- end }}

    {{- range $profile := $.Values.profiles }}
      {{- $profileDefs := get $profileDefs (printf "elCicdDefs-%s-%s" $appName $profile) }}
      {{- include "elCicdChart.mergeMapInto" (list $ $profileDefs $elCicdDefs) }}
    {{- end }}
  {{- end }}
{{- end }}

{{- define "elCicdChart.processAppNames" }}
  {{- $allTemplates := list }}
  {{- range $template := $.Values.templates  }}
    {{- if $template.appNames }}
      {{- include "elCicdChart.processTemplateAppnames" (list $ $template) }}
      {{- range $appName := $template.appNames }}
        {{- $newTemplate := deepCopy $template }}
        {{- $_ := set $newTemplate "appName" $appName }}
        {{- $allTemplates = append $allTemplates $newTemplate }}
      {{- end }}
    {{- else }}
      {{- $allTemplates = append $allTemplates $template }}
    {{- end }}
  {{- end }}
  {{ $_ := set $.Values "allTemplates" $allTemplates }}
{{- end }}

{{- define "elCicdChart.processTemplateAppnames" }}
  {{- $ := index . 0 }}
  {{- $template := index . 1 }}
  {{- if kindIs "string" $template.appNames }}
    {{- $appNames := $template.appNames }}
    {{- $matches := regexFindAll $.Values.PARAM_REGEX $appNames -1 }}
    {{- range $elCicdRef := $matches }}
      {{- $elCicdDef := regexReplaceAll $.Values.PARAM_REGEX $elCicdRef "${1}" }}

      {{- $paramVal := get $.Values.elCicdDefs $elCicdDef }}
      {{ if or (kindIs "string" $paramVal) }}
        {{- $appNames = replace $elCicdRef (toString $paramVal) $appNames }}
      {{- end }}
      {{- $appNames = $paramVal }}
    {{- end }}

    {{- $_ := set $template "appNames" $appNames }}
    {{- include "elCicdChart.processTemplateAppnames" . }}
  {{- else if not (kindIs "slice" $template.appNames) }}
    {{- fail (printf "appNames must be either a variable or a list: %s" $template.appNames )}}
  {{- end }}
{{- end }}

{{- define "elCicdChart.processTemplates" }}
  {{- $ := index . 0 }}
  {{- $templates := index . 1 }}
  {{- $elCicdDefs := index . 2 }}

  {{- range $template := $templates }}
    {{- $_ := set $template "appName" ($template.appName | default $.Values.appName) }}
    {{- $_ := required "elCicdChart must define template.appName or $.Values.appName!" $template.appName }}
    {{- $templateDefs := deepCopy $elCicdDefs }}
    {{- $_ := set $templateDefs "APP_NAME" ($templateDefs.APP_NAME | default $template.appName) }}

    {{- include "elCicdChart.mergeMapInto" (list $ $template.elCicdDefs $templateDefs) }}
    {{- include "elCicdChart.mergeProfileDefs" (list $ $template $templateDefs) }}

    {{- include "elCicdChart.processMap" (list $ $template $templateDefs) }}
  {{- end }}
{{- end }}

{{- define "elCicdChart.processMap" }}
  {{- $ := index . 0 }}
  {{- $map := index . 1 }}
  {{- $elCicdDefs := index . 2 }}

  {{- range $key, $value := $map }}
    {{- if not $value }}
      {{- $_ := set $map $key dict }}
    {{- else }}
      {{- $args := (list $ $map $key $elCicdDefs) }}
      {{- if (kindIs "map" $value) }}
        {{- include "elCicdChart.processMap" (list $ $value $elCicdDefs) }}
      {{- else if (kindIs "slice" $value) }}
        {{- include "elCicdChart.processSlice" (list $ $map $key $elCicdDefs) }}
      {{- else if (kindIs "string" $value) }}
          {{- include "elCicdChart.processMapValue" (list $ $map $key $elCicdDefs list) }}
      {{- end  }}

      {{- if (get $map $key) }}
        {{- include "elCicdChart.processMapKey" (list $ $map $key $elCicdDefs list) }}
      {{- else }}
        {{- $_ := unset $map $key }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}

{{- define "elCicdChart.processMapValue" }}
  {{- $ := index . 0 }}
  {{- $map := index . 1 }}
  {{- $key := index . 2 }}
  {{- $elCicdDefs := index . 3 }}
  {{- $processDefList := index . 4}}

  {{- $value := get $map $key }}
  {{- $matches := regexFindAll $.Values.PARAM_REGEX $value -1 }}
  {{- range $elCicdRef := $matches }}
    {{- $elCicdDef := regexReplaceAll $.Values.PARAM_REGEX $elCicdRef "${1}" }}
    {{- include "elCicdChart.circularReferenceCheck" (list $value $key $elCicdRef $elCicdDef $processDefList) }}
    {{- $processDefList = append $processDefList $elCicdDef }}

    {{- $paramVal := get $elCicdDefs $elCicdDef }}
    {{ if (kindIs "string" $paramVal) }}
      {{- $value = replace $elCicdRef (toString $paramVal) $value }}
    {{- else }}
      {{- if (kindIs "map" $paramVal) }}
        {{- $paramVal = deepCopy $paramVal }}
      {{- else if (kindIs "slice" $paramVal) }}
        {{- if (kindIs "map" (first $paramVal)) }}
          {{- $newList := list }}
          {{- range $el := $paramVal }}
            {{- $newList = append $newList (deepCopy $el) }}
          {{- end }}
          {{- $paramVal = $newList }}
        {{- end }}
      {{- end }}

      {{- $value = $paramVal }}
    {{- end }}
  {{- end }}

  {{- if $matches }}
    {{- $_ := set $map $key $value }}
    {{- if $value }}
      {{- if or (kindIs "map" $value) }}
        {{- include "elCicdChart.processMap" (list $ $value $elCicdDefs) }}
      {{- else if (kindIs "slice" $value) }}
        {{- include "elCicdChart.processSlice" (list $ $map $key $elCicdDefs) }}
      {{- else if (kindIs "string" $value) }}
        {{- include "elCicdChart.processMapValue" (list $ $map $key $elCicdDefs $processDefList) }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}

{{- define "elCicdChart.processMapKey" }}
  {{- $ := index . 0 }}
  {{- $map := index . 1 }}
  {{- $key := index . 2 }}
  {{- $elCicdDefs := index . 3 }}
  {{- $processDefList := index . 4}}

  {{- $value := get $map $key }}
  {{- $oldKey := $key }}
  {{- $matches := regexFindAll $.Values.PARAM_REGEX $key -1 }}
  {{- range $elCicdRef := $matches }}
    {{- $elCicdDef := regexReplaceAll $.Values.PARAM_REGEX $elCicdRef "${1}" }}
    {{- include "elCicdChart.circularReferenceCheck" (list $value $key $elCicdRef $elCicdDef $processDefList) }}
    {{- $processDefList = append $processDefList $elCicdDef }}
    
    {{- $paramVal := get $elCicdDefs $elCicdDef }}
    {{ $_ := unset $map $key }}
    {{- $key = replace $elCicdRef (toString $paramVal) $key }}
  {{- end }}
  {{- if ne $oldKey $key }}
    {{- $_ := unset $map $oldKey }}
  {{- end }}
  {{- if and $matches (ne $oldKey $key) $key }}
    {{- $_ := set $map $key $value }}
    {{- include "elCicdChart.processMapKey" (list $ $map $key $elCicdDefs $processDefList) }}
  {{- end }}
{{- end }}

{{- define "elCicdChart.processSlice" }}
  {{- $ := index . 0 }}
  {{- $map := index . 1 }}
  {{- $key := index . 2 }}
  {{- $elCicdDefs := index . 3 }}

  {{- $list := get $map $key }}
  {{- $newList := list }}
  {{- range $element := $list }}
    {{- if and (kindIs "map" $element) }}
      {{- include "elCicdChart.processMap" (list $ $element $elCicdDefs) }}
    {{- else if (kindIs "string" $element) }}
      {{- $matches := regexFindAll $.Values.PARAM_REGEX $element -1 }}
      {{- range $elCicdRef := $matches }}
        {{- $elCicdDef := regexReplaceAll $.Values.PARAM_REGEX $elCicdRef "${1}" }}
        {{- $paramVal := get $elCicdDefs $elCicdDef }}
        {{- if (kindIs "string" $paramVal) }}
          {{- $element = replace $elCicdRef (toString $paramVal) $element }}
        {{- else if and (kindIs "map" $paramVal) }}
          {{- include "elCicdChart.processMap" (list $ $paramVal $elCicdDefs) }}
          {{- $element = $paramVal }}
        {{- end }}
      {{- end }}
    {{- end }}

    {{- if $element }}
      {{- $newList = append $newList $element }}
    {{- end }}
  {{- end }}

  {{- if eq $key "anyProfiles" }}
# Rendered -> list {{ $list }}
# Rendered -> newList {{ $newList }}
  {{- end }}
  {{- $_ := set $map $key $newList }}
{{- end }}

{{- define "elCicdChart.mergeMapInto" }}
  {{- $ := index . 0 }}
  {{- $srcMap := index . 1 }}
  {{- $destMap := index . 2 }}

  {{- if $srcMap }}
    {{- range $key, $value := $srcMap }}
      {{- $_ := set $destMap $key $value }}
    {{- end }}
  {{- end }}
{{- end }}

{{- define "elCicdChart.circularReferenceCheck" }}
  {{- $value := index . 0 }}
  {{- $key := index . 1 }}
  {{- $elCicdRef := index . 2 }}
  {{- $elCicdDef := index . 3 }}
  {{- $processDefList := index . 4}}
  
  {{- if has $elCicdDef $processDefList }}
    {{- fail (printf "Circular elCicdDefs reference: '%s' in '%s: %s'" $elCicdRef $key $value) }}
  {{- end }}
{{- end }}

{{ define "elCicdChart.skippedTemplate" }}
# EXCLUDED BY PROFILES: {{ index . 1 }} -> {{ index . 2 }}
{{- end }}
