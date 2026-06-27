
{{- define "elcicd-renderer.preProcessFilesAndConfig" }}
  {{- $ := get . "$" }}
  {{- $tplElCicdDefs := .elCicdDefs }}

  {{- range $variable, $value := $tplElCicdDefs }}
    {{- if $value }}
      {{- if or (kindIs "map" $value) }}
        {{- include "elcicd-renderer.preProcessFilesAndConfig" (dict "$" $ "elCicdDefs" $value) }}
      {{- else if (kindIs "string" $value) }}
        {{- if (regexMatch $.Values.__EC_IMPORT_FILES_PREFIX_REGEX $variable) }}
          {{- $filePath := (regexReplaceAll $.Values.__EC_IMPORT_FILES_PREFIX_REGEX  $variable "" | trimSuffix ">") }}
          {{- if (hasPrefix $.Values.__EC_GLOB_PREFIX $variable) }}
            {{- $_ := set $tplElCicdDefs $variable (($.Files.Glob $filePath).AsConfig | fromYaml) }}
          {{- else }}
            {{- $newValue := $.Files.Get $filePath }}
            {{- $_ := set $tplElCicdDefs $variable (toString $newValue) }}
          {{- end }}
        {{- end }}
      {{- end }}
    {{- end }}
  {{- end }}

  {{- range $variable, $value := $tplElCicdDefs }}
    {{- if (kindIs "string" $value) }}
      {{- if (hasPrefix $.Values.__EC_CONFIG_PREFIX $variable) }}
        {{- include "elcicd-renderer.asConfig" (dict "$" $ "variable" $variable "value" $value "elCicdDefs" $tplElCicdDefs) }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}

{{- define "elcicd-renderer.asConfig" }}
  {{- $ := get . "$" }}
  {{- $variable := .variable }}
  {{- $value := .value }}
  {{- $tplElCicdDefs := .elCicdDefs }}

  {{- $_ := unset $tplElCicdDefs $variable }}
  {{- $variable = ( $variable | trimPrefix $.Values.__EC_CONFIG_PREFIX | trimSuffix ">") }}
  {{- $newValue := dict }}
  {{- range $configLine := (regexSplit "\n" $value -1) }}
    {{- $keyValue := (regexSplit "\\s*=\\s*" $configLine -1) }}
    {{- if (eq (len $keyValue) 2) }}
      {{- $propKey := (index $keyValue 0) }}
      {{- if and (index $keyValue 1) (eq (regexFind "^\\w[^\\s]*" $propKey) $propKey) }}
        {{- $_ := set $newValue $propKey (index $keyValue 1) }}
      {{- end }}
    {{- end }}
  {{- end }}

  {{- $_ := set $tplElCicdDefs $variable $newValue }}
{{- end }}