{{/*
Kustomization
*/}}
{{- define "elCicdKubernetes.kustomization" }}
  {{- $ := index . 0 }}
  {{- $kustValues := index . 1 }}
  {{- $_ := set $kustValues "kind" "Kustomization" }}
  {{- $_ := set $kustValues "apiVersion" "kustomize.config.k8s.io/v1beta1" }}
  {{- include "elCicdCommon.apiObjectHeader" . }}

  {{- range $field, $fieldValue := ($kustValues.fields | default dict) }}
{{ $field }}: {{ $fieldValue | toYaml | nindent 2 }}
  {{- end }}
{{- end }}

{{- define "elCicdKubernetes.chart-yaml" }}
  {{- $ := index . 0 }}
  {{- $chartValues := index . 1 }}
apiVersion: {{ $chartValues.apiVersion | default "v2" }}
name: {{ $chartValues.objName }}
{{- $semverRegex := "^(?P<major>0|[1-9]\\d*)\\.(?P<minor>0|[1-9]\\d*)\\.(?P<patch>0|[1-9]\\d*)(?:-(?P<prerelease>(?:0|[1-9]\\d*|\\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\\.(?:0|[1-9]\\d*|\\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\\+(?P<buildmetadata>[0-9a-zA-Z-]+(?:\\.[0-9a-zA-Z-]+)*))?$" }}
  {{- if (and $chartValues.version (regexMatch $semverRegex $chartValues.version)) }}
version: {{ semver (required "A valid chart version is required" $chartValues.version) | toYaml }}
  {{- else }}
    {{- fail (printf "Missing valid semver2 compatible version: %s" $chartValues.version) }}
  {{- end }}
  {{- $whiteList := list "kubeVersion"
                         "description"
                         "type"
                         "keywords"
                         "home"
                         "sources"
                         "dependencies"
                         "maintainers"
                         "icon"
                         "appVersion"
                         "deprecated"
                         "annotations" }}
  {{- include "elCicdCommon.outputToYaml" (list $ $chartValues $whiteList 0) }}
{{- end }}
