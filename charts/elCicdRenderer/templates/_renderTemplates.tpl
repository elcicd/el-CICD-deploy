# SPDX-License-Identifier: LGPL-2.1-or-later

{{- define "elCicdRenderer.render" }}
  {{- $ := . }}
  
  {{- $_ := set $.Values "EL_CICD_DEPLOYMENT_TIME" (now | date "Mon Jan 2 15:04:05 MST 2006") }}

  {{- include "elCicdRenderer.initElCicdRenderer" . }}

  {{- include "elCicdRenderer.createNamespaces" . }}

  {{- include "elCicdRenderer.mergeProfileDefs" (list $ $.Values.elCicdDefs "" "") }}

  {{- include "elCicdRenderer.generateAllTemplates" . }}

  {{- include "elCicdRenderer.processTemplates" (list $ $.Values.allTemplates) }}
  
  {{- if $.Values.collateValues }}
    {{- include "elCicdCommon.outputValues" . }}
  {{- else }}
    {{- $skippedList := list }}
    {{- range $template := $.Values.allTemplates  }}
      {{- $templateName := $template.templateName }}
      {{- if not (contains "." $templateName) }}
        {{- if eq $templateName "copyResource" }}
          {{- $templateName = "elCicdRenderer.copyResource" }}
        {{- else }}
          {{- $templateName = printf "%s.%s" $.Values.elCicdDefaults.templatesChart $template.templateName }}
        {{- end }}
      {{- end }}
---
      {{- include $templateName (list $ $template) }}
# Rendered -> {{ $template.templateName }} {{ $template.objName }}
    {{- end }}

    {{- $resultMap := dict }}
    {{- range $yamlMapKey, $rawYamlValue := $.Values }}
      {{- if and (hasPrefix "elCicdRawYaml" $yamlMapKey) (kindIs "map" $rawYamlValue) }}
        {{- range $yamlKey, $rawYaml := $rawYamlValue }}
          {{- $_ := set $resultMap $.Values.PROCESS_STRING_VALUE ($rawYaml | toString) }}
          {{- include "elCicdRenderer.processString" (list $ $resultMap $.Values.elCicdDefs) }}
          {{- $rawYaml = get $resultMap $.Values.PROCESS_STRING_VALUE }}
---
  {{ $rawYaml }}
# Rendered From {{ $yamlMapKey }} -> {{ $yamlKey }}
        {{- end }}
      {{- end }}
    {{- end }}

    {{- if $.Values.renderValuesForKust }}
      {{- include "elCicdCommon.outputValues" . }}
    {{- end }}
---
# Profiles: {{ $.Values.elCicdProfiles }}
    {{- range $skippedTemplate := $.Values.skippedTemplates }}
      {{- include "elCicdRenderer.skippedTemplateLog" $skippedTemplate }}
    {{- end }}
  {{- end }}
{{- end }}
