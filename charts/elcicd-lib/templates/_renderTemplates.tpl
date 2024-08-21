# SPDX-License-Identifier: LGPL-2.1-or-later

{{/*
  ======================================
  elcicd-renderer.render
  ======================================

  PARAMETERS LIST:
    . -> should always be root of chart

  ======================================

  ENTRY POINT for el-CICD Charts.  To use el-CICD Charts create a Helm chart with a single .tpl file.
  See the sibling elcicd-chart or usable example:

  {{- if eq .Values.outputMergedValuesYaml true }}
    {{- $_ := unset .Values "outputMergedValuesYaml" }}
    {{- .Values | toYaml }}
  {{- else }}
    {{- include "elcicd-renderer.render" . }}
  {{- end }}

  Chart.yaml should have the following dependencies:

  # Chart.yaml snippet
  dependencies:
  - name: elcicd-renderer
  version: 0.1.0
  repository: file://../elcicd-renderer
  - name: elcicd-kubernetes
    version: 0.1.0
    repository: file://../elcicd-kubernetes
  - name: elcicd-common
    version: 0.1.0
    repository: file://../elcicd-common

  The elcicd-kubernetes and elcicd-common library charts are technically optional, but should be added if
  deploying to Kubernetes.  Both of the those charts support el-CICD templates for common application
  deployment Kubernetes resources.

  =====================================

  Supported values of el-CICD Chart:

  elCicdProfiles
    List of active profiles for rendering. Usually entered only on the command line
    when rendering.

  elCicdDefs
  elCicdDefs-<profile>
  elCicdDefs-<baseObjName>
  elCicdDefs-<objName>
  elCicdDefs-<baseObjName>-<profile>
  elCicdDefs-<objName>-<profile>
    Variables are defined under these dictionaries, where keys are variable names.
    Variables may reference other variables, may be any type of valid YAML data,
    and order is not important.  elCicdDefs with named profiles or objNames will
    only be used when the profile is active or a template using that objName is being rendered.
    The order of precedence is defined as above, with the more specific the variable definition
    relative to the profile and then the objName.

    Variables are defined and referenced in templates in the following manner:

    elCicdDefs:
      FIRST_VAR: a string
      SECOND_VAR:
      - a list
      THIRD_VAR:
        a: map

    Use a backslash for escaping:

      \$<variableName> # NOTE: backslashes will be removed post-rendering

  elCicdTemplates
    List of el-CICD chart template to render.  Order is not important.  Basic form is as follows:

    - templateName: <template name>
      objName: <resource name to be rendered>
      objNames: <list of resource names to be rendered>
      namespace: <optional list of namespace(s)to deploy resource to>
      namespaces: <optional list of namespace(s)to deploy resource to>
      elCicdDefs: <list of variables only applicable to this template>
      elCicdDefs-<profile>: <list of variables only applicable to this template when profile is active>
      elCicdDefs-<objectName>-<profile>: <list of variables only applicable to a template with objName when profile is active>
      <template values to set>

      objName and objNames are mutually exclusive, with objNames given precedence.  One or the other MUST be defined.
      namespace and namespaces are mutually exclusive and optional, with namespaces given precedence.  They only needed
      if the resource is to be rendered outside the chart's namespace.  elCicdVariables can be used for either.  namespaces
      and objNames are defined as lists.

      elCicdDefs defined in the specific template are given precedence.  Note the optional use objName when defining elCicdDefs,
      since the list of objNames implies multiple different objNames.

      Special objName namespace references for inserting for generating an objName or namespace values:
      $<> - insert the baseObjName/baseNamespaceName from the objNames/namespaces list
      $<#> - index of current baseObjName/baseNamespaceName in the objNames/namespaces list
      For example:

      namespaces:
      - foo
      - bar
      namespace: $<>-$<#>

      Will be rendered as:
      metadata:
        namespace: foo-1

      metadata:
        namespace: bar-2

      If objNames and owere used in the above:
      objNames:
      - foo
      - bar
      objeName: $<>-$<#>

      Would produce:
      metadata:
        name: foo-1

      metadata:
        name: bar-2


  valuesYamlToStdOut
    If set to true, will NOT render the chart, but instead render the el-CICD processed Values object for debugging purposes.

  =====================================

  General rendering process:

  1. Intialization of data for chart (elcicd-renderer.initElCicdRenderer)
  2. Evaluate chart-level elCicdDefs* to get final list of variable definitions.
  3. Collect all template lists from all included values.yaml files.
  3. Filter the list of templates to be rendered based on the current list of active profiles.
  4. Realize the complete list of templates to be rendered based on any objNames or namespaces matrices per template.
  5. Process all templates, replacing el-CICD variable references with their values.
  5. Add comments describing which templates were rendered and which were skipped due to profile filtering.

  NOTE: if valuesYamlToStdOut or global.valuesYamlToStdOut is true, then only the processed Values values will
        be output.
*/}}
{{- define "elcicd-renderer.render" }}
  {{- $ := . }}

  {{/* HACK (v3.15): global values map not automatically initialized in library charts.  Works if globals defined in chart, though. */}}
  {{- $_ := set $.Values "global" ($.Values.global | default dict) }}

  {{- if (or $.Values.renderPreprocessedValues $.Values.global.renderPreprocessedValues) }}
    {{- $.Values | toYaml }}
  {{- else }}
    {{- $_ := set $.Values "__EC_DEPLOYMENT_TIME" (now | date "Mon Jan 2 15:04:05 MST 2006") }}
    {{- $_ := set $.Values "__EC_DEPLOYMENT_TIME_NUM" (now | date "2006_01_02_15_04_05") }}

    {{- include "elcicd-renderer.initElCicdRenderer" . }}

    {{- include "elcicd-renderer.preProcessElCicdDefsMapNames" (list $ $.Values $.Values.elCicdDefs) }}
    {{- include "elcicd-renderer.mergeElCicdDefs" (list $ $.Values $.Values.elCicdDefs "" "") }}

    {{- $_ := set $.Values.elCicdDefs "HELM_RELEASE_NAME" $.Release.Name }}
    {{- $_ := set $.Values.elCicdDefs "HELM_RELEASE_NAMESPACE" $.Release.Namespace }}

    {{- include "elcicd-renderer.gatherElCicdTemplates" $ }}

    {{- include "elcicd-renderer.filterTemplates" (list $ $.Values.elCicdTemplates) }}

    {{- include "elcicd-renderer.generateAllTemplates" (list $ $.Values.renderingTemplates) }}

    {{- include "elcicd-renderer.processTemplates" (list $ $.Values.allTemplates) }}

    {{- if (or $.Values.renderProcessedValues $.Values.global.renderProcessedValues) }}
      {{ $.Values | toYaml }}
    {{- else }}
      {{- range $template := $.Values.allTemplates }}
        {{- include "elcicd-renderer.renderTemplate" (list $ $template) }}
      {{- end }}
---
# Profiles: {{ $.Values.elCicdProfiles }}
      {{- range $skippedTemplate := $.Values.skippedTemplates }}
# EXCLUDED BY PROFILES: {{ index $skippedTemplate 0 }} -> {{ index $skippedTemplate 1 }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}

{{- define "elcicd-renderer.renderTemplate" }}
  {{- $ := index . 0 }}
  {{- $template := index . 1 }}

  {{- $templateName := $template.templateName | default "elcicd-renderer.__render-default" }}
  {{- if not (contains "." $templateName) }}
    {{- if eq $templateName "copyResource" }}
      {{- $templateName = "elcicd-renderer.copyResource" }}
    {{- else }}
      {{- $templateName = printf "%s.%s" $.Values.elCicdDefaults.templatesChart $template.templateName }}
    {{- end }}
  {{- end }}
---
  {{- include $templateName . }}

  {{- if $template.templateName }}
# Rendered el-CICD Chart Template -> "{{ $template.templateName }}" {{ $template.objName | default ($template.metadata).name }}
  {{- end }}
{{- end }}

{{- define "elcicd-renderer.__render-default" }}
  {{- $ := index . 0 }}
  {{- $template := index . 1 }}

  {{- $_ := required "template or templateName must be defined for an el-CICD Chart template" $template.template }}

  {{- if not (eq (toString $template.kubeObject) "false") }}
    {{- $_ := set $template.template "apiVersion" ($template.template.apiVersion | default $template.apiVersion | default "v1") }}
    {{- $_ := set $template.template "kind" ($template.template.kind | default $template.kind) }}
    {{- $_ := required "Kubernetes API objects require a \"kind\"" $template.template.kind }}

    {{- $metadata := $template.template.metadata | default dict }}
    {{- $_ := set $template.template "metadata" $metadata }}
    {{- $_ := set $metadata "name" ($metadata.name | default $template.objName | default $.Values.elCicdDefaults.objName) }}
    {{- $_ := set $template "objName" ($template.objName | default $metadata.name) }}
    {{- $_ := set $metadata "namespace" ($metadata.namespace | default $template.namespace | default $.Release.Namespace) }}

    {{- $_ := set $metadata "annotations" ($metadata.annotations | default dict) }}
    {{- $_ := set $template "annotations" ($template.annotations | default dict) }}
    {{- $_ := set $metadata "annotations" (merge $metadata.annotations $template.annotations) }}

    {{- $_ := set $metadata "labels" ($metadata.labels | default dict) }}
    {{- include "elcicd-common.labels" (list $ $metadata.labels)  }}
    {{- $_ := set $metadata.labels "elcicd.io/selector" (include "elcicd-common.elcicdLabels" .) }}
    {{- $_ := set $template "labels" ($template.labels | default dict) }}
    {{- $_ := set $metadata "labels" (merge $metadata.labels $template.labels) }}
  {{- end }}

  {{- toYaml $template.template }}
# Rendered YAML Template -> kind: "{{ $template.template.kind }}" name: "{{ (($template.template).metadata).name }}"
{{- end }}
