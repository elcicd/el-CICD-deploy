
{{- define "elCicdRenderer.preProcessFilesAndConfig" }}
  {{- $ := index . 0 }}
  {{- $tplDefs := index . 1 }}
  
  {{- range $param, $value := $tplDefs }}
    {{- if $value }}
      {{- if or (kindIs "map" $value) }}
        {{- include "elCicdRenderer.preProcessFilesAndConfig" (list $ $value) }}
      {{- else if (kindIs "string" $value) }}
        {{- if or (hasPrefix $.Values.FILE_PREFIX $value) }}
          {{- $filePath := ( $value | trimPrefix $.Values.FILE_PREFIX | trimSuffix "}") }}
          {{- $value = $.Files.Get $filePath }}
          {{- $_ := set $tplDefs $param (toString $value) }}
        {{- end }}
  
        {{- if (hasPrefix $.Values.CONFIG_PREFIX $param) }}
          {{- include "elCicdRenderer.asConfig" (list $ $param $value $tplDefs) }}
        {{- end }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}

{{- define "elCicdRenderer.asConfig" }}
  {{- $ := index . 0 }}
  {{- $param := index . 1 }}
  {{- $value := index . 2 }}
  {{- $tplDefs := index . 3 }}
  
  {{- $_ := unset $tplDefs $param }}
  {{- $param = ( $param | trimPrefix $.Values.CONFIG_PREFIX | trimSuffix "}") }}
  {{- $newValue := dict }}
  {{- range $configLine := (regexSplit "\n" $value -1) }}
    {{- $keyValue := (regexSplit "\\s*=\\s*" $configLine -1) }}
    {{- if (eq (len $keyValue) 2) }}
      {{- if (index $keyValue 1) }}
        {{- $_ := set $newValue (index $keyValue 0) (index $keyValue 1) }}
      {{- end }}
    {{- end }}
  {{- end }}
  
  {{- $_ := set $tplDefs $param $newValue }}
{{- end }}