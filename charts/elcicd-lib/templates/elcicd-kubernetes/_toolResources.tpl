{{/*
el-CIDC support for templating an a kustomization.  No expectation of known keys is given.
*/}}
{{- define "elcicd-kubernetes.kustomization" }}
  {{- $ := get . "$" }}
  {{- $kustValues := get . "elCicdTemplate" }}

  {{- $_ := set $kustValues "kind" "Kustomization" }}
  {{- $_ := set $kustValues "apiVersion" ($kustValues.apiVersion | default "kustomize.config.k8s.io/v1beta1") }}
  {{- include "elcicd-common.apiObjectHeader" . }}

  {{- range $field, $fieldValue := ($kustValues.fields | default dict) }}
{{ $field }}: {{ $fieldValue | toYaml | nindent 2 }}
  {{- end }}
{{- end }}

{{/*
el-CIDC support for templating an a Chart.yaml for generating a Helm Chart.
*/}}
{{- define "elcicd-kubernetes.chart-yaml" }}
  {{- $ := get . "$" }}
  {{- $chartValues := get . "elCicdTemplate" }}

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
  {{- include "elcicd-common.outputToYaml" (dict "$" $ "elCicdTemplate" $chartValues "whiteList" $whiteList) }}
{{- end }}
