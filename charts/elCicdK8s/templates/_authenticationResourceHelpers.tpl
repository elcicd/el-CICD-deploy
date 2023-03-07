{{/*
genericRoleDefinition: all ClusterRoles and Roles have this structure
*/}}
{{- define "elCicdK8s.genericRoleDefinition" }}
{{- $ := index . 0 }}
{{- $roleValues := index . 1 }}
{{- $_ := set $roleValues "apiVersion" "rbac.authorization.k8s.io/v1" }}
{{- include "elCicdCommon.apiObjectHeader" . }}
{{- if $roleValues.aggregationRule }}
aggregationRule: {{ $roleValues.aggregationRule | toYaml | nindent 2 }}
{{- end }}
{{- if $roleValues.rules }}
rules:
{{ $roleValues.rules | toYaml }}
{{- end }}
{{- end }}

{{/*
genericRoleBindingDefinition: all ClusterRoleBindings and RoleBindings have this structure
*/}}
{{- define "elCicdK8s.genericRoleBindingDefinition" }}
{{- $ := index . 0 }}
{{- $roleBindingValues := index . 1 }}
{{- $_ := set $roleBindingValues "apiVersion" "rbac.authorization.k8s.io/v1" }}
{{- include "elCicdCommon.apiObjectHeader" . }}
roleRef: {{ $roleBindingValues.roleRef | toYaml | nindent 2 }}
subjects:
{{ $roleBindingValues.subjects | toYaml }}
{{- end }}
