
{{- define "elcicd-renderer.preProcessFilesAndConfig" }}
  {{- $ := index . 0 }}
  {{- $tplElCicdDefs := index . 1 }}
  
  {{- range $param, $value := $tplElCicdDefs }}
    {{- if $value }}
      {{- if or (kindIs "map" $value) }}
        {{- include "elcicd-renderer.preProcessFilesAndConfig" (list $ $value) }}
      {{- else if (kindIs "string" $value) }}
        {{- if (hasPrefix $.Values.__EC_FILE_PREFIX $value) }}
          {{- $filePath := ( $value | trimPrefix $.Values.__EC_FILE_PREFIX | trimSuffix ">") }}
          {{- $value = $.Files.Get $filePath }}
          {{- $_ := set $tplElCicdDefs $param (toString $value) }}
        {{- end }}
  
        {{- if (hasPrefix $.Values.__EC_CONFIG_PREFIX $param) }}
          {{- include "elcicd-renderer.asConfig" (list $ $param $value $tplElCicdDefs) }}
        {{- end }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}

{{- define "elcicd-renderer.asConfig" }}
  {{- $ := index . 0 }}
  {{- $param := index . 1 }}
  {{- $value := index . 2 }}
  {{- $tplElCicdDefs := index . 3 }}
  
  {{- $_ := unset $tplElCicdDefs $param }}
  {{- $param = ( $param | trimPrefix $.Values.__EC_CONFIG_PREFIX | trimSuffix ">") }}
  {{- $newValue := dict }}
  {{- range $configLine := (regexSplit "\n" $value -1) }}
    {{- $keyValue := (regexSplit "\\s*=\\s*" $configLine -1) }}
    {{- if (eq (len $keyValue) 2) }}
      {{- if (index $keyValue 1) }}
        {{- $_ := set $newValue (index $keyValue 0) (index $keyValue 1) }}
      {{- end }}
    {{- end }}
  {{- end }}
  
  {{- $_ := set $tplElCicdDefs $param $newValue }}
{{- end }}