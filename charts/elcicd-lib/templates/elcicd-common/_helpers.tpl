{{/*
  ======================================
  elcicd-kubernetes.apiObjectHeader
  ======================================

  PARAMETERS LIST:
    . -> should always be root of chart
    $template -> elCicd template

  ======================================

  DEFAULT KEYS
    apiVersion
    kind

  ======================================

  el-CICD SUPPORTING TEMPLATES:
  "elcicd-common.metadata"

  ======================================

  General header for a Kubernetes compliant resource.
*/}}
{{- define "elcicd-common.apiObjectHeader" }}
{{- $ := index . 0 }}
{{- $template := index . 1 }}
apiVersion: {{ $template.apiVersion | default "v1" }}
kind: {{ required "Kubernetes API objects require a \"kind\"" $template.kind }}
{{- if $template.metadata }}
metadata:
{{ toYaml $template.metadata | nindent 2 }}
{{- else }}
  {{- include "elcicd-common.metadata" . }}
{{- end }}
{{- end }}

{{/*
  ======================================
  elcicd-kubernetes.apiMetadata
  ======================================

  PARAMETERS LIST:
    . -> should always be root of chart
    $template -> elCicd template

  ======================================

  DEFAULT KEYS
    [metadata]:
      annotations
      labels
      name
      namespace

  ======================================

  el-CICD SUPPORTING TEMPLATES:
    "elcicd-common.labels"

  ======================================

  General header for a Kubernetes compliant resource metadata.
*/}}
{{- define "elcicd-common.metadata" }}
{{- $ := index . 0 }}
{{- $metadataValues := index . 1 }}
metadata:
  {{- $_ := set $metadataValues "annotations" (mergeOverwrite ($metadataValues.annotations | default dict) ($.Values.elCicdDefaults.annotations | default dict)) }}
  {{- if $metadataValues.annotations }}
  annotations:
    {{- range $key, $value := $metadataValues.annotations }}
    {{ $key }}: {{ $value | quote }}
    {{- end }}
  {{- end }}
  {{- $_ := set $metadataValues "labels" (mergeOverwrite ($metadataValues.labels | default dict) ($.Values.elCicdDefaults.labels | default dict)) }}
  labels:
    {{- include "elcicd-common.labels" (list $ $metadataValues.labels) }}
    {{- $_ := set $metadataValues.labels "elcicd.io/selector" (include "elcicd-common.elcicdLabels" .) }}
    {{- $metadataValues.labels | toYaml | nindent 4 }}
  name: {{ required (printf "Unnamed apiObject Name in template: %s!" $metadataValues.templateName) $metadataValues.objName }}
  namespace: {{ $metadataValues.namespace | default $metadataValues.tplElCicdDefs.NAME_SPACE }}
{{- end }}

{{/*
  ======================================
  elcicd-kubernetes.labels
  ======================================

  PARAMETERS LIST:
    . -> should always be root of chart
    $template -> elCicd template

  ======================================

  HELPER KEYS
  ---
    helm.sh/chart -> .Chart.Name-.Chart.Version
    app.kubernetes.io/instance -> .Release.Name
    app.kubernetes.io/managed-by -> .Release.Service
    app.kubernetes.io/version -> .Chart.AppVersion
    elcicdSelector -> $template.objName

  ======================================

  el-CICD SUPPORTING TEMPLATES:
    "elcicd-common.elcicdLabels"

  ======================================

  Generates some default labels for a Kubernetes compliant resource based on the values in Chart.yaml.
*/}}
{{- define "elcicd-common.labels" }}
  {{- $ := index . 0 }}
  {{- $labels := index . 1 }}

  {{- $_ := set $labels "app.kubernetes.io/instance" (toString $.Release.Name) }}
  {{- $_ := set $labels "app.kubernetes.io/managed-by" $.Release.Service }}

  {{- if $.Chart.AppVersion }}
    {{- $_ := set $labels "app.kubernetes.io/version" $.Chart.AppVersion }}
  {{- end }}

  {{- $_ := set $labels "helm.sh/chart" (printf "%s-%s" $.Chart.Name $.Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-") }}
{{- end }}

{{/*
  ======================================
  elcicd-kubernetes.elcicdLabels
  ======================================

  PARAMETERS LIST:
    . -> should always be root of chart
    $template -> elCicd template

  ======================================

  HELPER KEYS
  ---
    elcicdSelector -> $template.objName

  ======================================

  Generates a selector label, elcicd.io/selector.
*/}}
{{- define "elcicd-common.elcicdLabels" }}
  {{- $ := index . 0 }}
  {{- $template := index . 1 }}

  {{- $selector := $template.elcicdSelector | default (regexReplaceAll "[^\\w-.]" $template.objName "-") }}
  {{- if (gt (len $selector) 63 ) }}
    {{- $selector = $selector | trunc 48 | trimSuffix "-"}}
    {{- $selectorSuffix := derivePassword 1 "long" $selector $selector "elcicd.org"  }}
    {{- $selectorSuffix = (regexReplaceAll "[^\\w-.]"  $selectorSuffix  "_" )}}
    {{- $selectorSuffix = (regexReplaceAll "[-_.]$"  $selectorSuffix  "Z" )}}
    {{- $selector = printf "%s-%s" $selector $selectorSuffix }}
  {{- end }}

  {{- $selector }}
{{- end }}

{{/*
  ======================================
  elcicd-kubernetes.outputToYaml
  ======================================

  PARAMETERS LIST:
    . -> should always be root of chart
    $template -> elCicd template
    $whiteList -> list of whitelisted keys output to YAML if defined in the $.Values map

  This is a catch-all that renders all extraneous key/values pairs that don't have helper keys or structures.
  Checks the template values for each resource's whitelist, and if it exists renders it properly.
*/}}
{{- define "elcicd-common.outputToYaml" }}
  {{- $ := index . 0 }}
  {{- $template := index . 1 }}
  {{- $whiteList := index . 2 }}

  {{- $defaultIndent := append . 2 }}
  {{- $indent := index $defaultIndent 3 | int }}

  {{- include "elcicd-common.setTemplateDefaultValue" . }}

  {{- range $key, $value := $template }}
    {{- if or (has $key $whiteList) (empty $whiteList) }}
      {{- if (kindIs "map" $value) }}
        {{- $key | nindent $indent }}:
        {{- $value | toYaml | nindent (int (add $indent 2)) }}
      {{- else if (kindIs "slice" $value) }}
        {{- $key | nindent $indent }}:
        {{- $value | toYaml | nindent $indent }}
      {{- else if kindIs "string" $value }}
        {{- $key | nindent $indent }}: {{ $value | quote }}
      {{- else }}
        {{- $key | nindent $indent }}: {{ $value }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}

{{/*
  ======================================
  elcicd-kubernetes.setTemplateDefaultValue
  ======================================

  PARAMETERS LIST:
    . -> should always be root of chart
    $template -> elCicd template
    $whiteList -> list of whitelisted keys to set default value, if it exists

  ======================================

  Support function for the outputToYaml function.  Assigns a value for anything in the whitelist
  that is empty and has n elCicdDefault value defined.
*/}}
{{- define "elcicd-common.setTemplateDefaultValue" }}
  {{- $ := index . 0 }}
  {{- $template := index . 1 }}
  {{- $whiteList := index . 2 }}

  {{- range $key := $whiteList }}
    {{- if not (hasKey $template $key) }}
      {{- $defaultValue := get $.Values.elCicdDefaults $key }}
      {{- if $defaultValue }}
        {{- $_ := set $template $key $defaultValue }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}

{{/*
  ======================================
  elcicd-kubernetes.kubeObjectMetadata
  ======================================

  PARAMETERS LIST:
    . -> should always be root of chart
    $template -> elCicd free form template

  Supports defining metadata for a free form Kubernetes compatible resource.
*/}}
{{- define "elcicd-common.kubeObjectMetadata" }}
  {{- $ := index . 0 }}
  {{- $template := index . 1 }}

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