{{/*
genericRoleDefinition: all ClusterRoles and Roles have this structure
*/}}
{{- define "elcicd-kubernetes.genericRoleDefinition" }}
  {{- $ := get . "$" }}
  {{- $roleValues := .elCicdTemplate }}

  {{- $_ := set $roleValues "apiVersion" ($roleValues.apiVersion | default "rbac.authorization.k8s.io/v1") }}
  {{- include "elcicd-common.apiObjectHeader" . }}
  {{- if $roleValues.aggregationRule }}
aggregationRule: {{ $roleValues.aggregationRule | toYaml | nindent 2 }}
  {{- end }}
  {{- if $roleValues.rules }}
rules: {{- $roleValues.rules | toYaml | nindent 0 }}
  {{- end }}
{{- end }}

{{/*
genericRoleBindingDefinition: all ClusterRoleBindings and RoleBindings have this structure
*/}}
{{- define "elcicd-kubernetes.genericRoleBindingDefinition" }}
  {{- $ := get . "$" }}
  {{- $genericRoleBindingBindingValues := .elCicdTemplate }}

  {{- $_ := set $genericRoleBindingBindingValues "apiVersion" ($genericRoleBindingBindingValues.apiVersion | default "rbac.authorization.k8s.io/v1") }}
  {{- include "elcicd-common.apiObjectHeader" . }}
roleRef: {{ $genericRoleBindingBindingValues.roleRef | toYaml | nindent 2 }}
subjects: {{ $genericRoleBindingBindingValues.subjects | toYaml | nindent 0}}
{{- end }}
