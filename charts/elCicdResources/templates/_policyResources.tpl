{{/*
ResourceQuota
*/}}
{{- define "elCicdResources.resourceQuota" }}
{{- $ := index . 0 }}
{{- $quotaValues := index . 1 }}
{{- $_ := set $quotaValues "kind" "ResourceQuota" }}
{{- $_ := set $quotaValues "apiVersion" "v1" }}
{{- include "elCicdResources.apiObjectHeader" . }}
spec:
  hard:
  {{- $quotaValues.hard | toYaml | nindent 4 }}
  {{- if $quotaValues.scopeSelector }}
  scopeSelector:
  {{- $quotaValues.scopeSelector | toYaml | nindent 4 }}
  {{- end }}
  {{- if $quotaValues.scopes }}
  scopes:
  {{- $quotaValues.scopes | toYaml | nindent 2 }}
  {{- end }}
{{- end }}