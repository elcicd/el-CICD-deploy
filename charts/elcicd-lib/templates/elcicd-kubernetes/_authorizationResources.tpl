
{{/*
  Defines templates for rendering Kubernetes workload resources, including:
  - ConfigMap
  - Secret
    - Image Registry (Docker) Secret
    - Service Account Token Secret
  - PersistentVolume
  - PersistentVolumeClaim

  In the following documentation:
  - HELPER KEYS - el-CICD template specific keys keys that can be used with that are NOT part of the Kubernetes
    resource, but rather conveniences to make defining Kubernetes resoruces less verbose or easier
  - DEFAULT KEYS - standard keys for the the Kubernetes resource, usually located at the top of the
    resource defintion or just under a standard catch-all key like "spec"
  - el-CICD SUPPORTING TEMPLATES - el-CICD templates that are shared among different el-CICD templates
    and called to render further data; e.g. every template calls "elcicd-common.apiObjectHeader", which
    in turn renders the metadata section found in every Kubernetes resource
*/}}

{{/*
  ======================================
  elcicd-kubernetes.clusterRole
  ======================================

  PARAMETERS LIST:
    . -> should always be root of chart
    $deployValues -> elCicd template for ClusterRole

  ======================================

  DEFAULT KEYS
  ---
    [spec]:
      aggregationRule
      rules

  ======================================

  el-CICD SUPPORTING TEMPLATES:
    "elcicd-common.apiObjectHeader"

  ======================================

  Defines a el-CICD template for a Kubernetes ClusterRole.
*/}}
{{- define "elcicd-kubernetes.clusterRole" }}
  {{- $ := get . "$" }}
  {{- $roleValues := get . "elCicdTemplate" }}

  {{- $_ := set $roleValues "kind" "ClusterRole" }}
  {{- include "elcicd-kubernetes.genericRoleDefinition" . }}
{{- end }}

{{/*
  ======================================
  elcicd-kubernetes.clusterRoleBinding
  ======================================

  PARAMETERS LIST:
    . -> should always be root of chart
    $deployValues -> elCicd template for ClusterRoleBinding

  ======================================

  DEFAULT KEYS
  ---
    [spec]:
      roleRef
      subjects

  ======================================

  el-CICD SUPPORTING TEMPLATES:
    "elcicd-common.apiObjectHeader"

  ======================================

  Defines a el-CICD template for a Kubernetes ClusterRoleBinding.
*/}}
{{- define "elcicd-kubernetes.clusterRoleBinding" }}
  {{- $ := get . "$" }}
  {{- $clusterRoleBindingValues := get . "elCicdTemplate" }}

  {{- $_ := set $clusterRoleBindingValues "kind" "ClusterRoleBinding" }}
  {{- include "elcicd-kubernetes.genericRoleBindingDefinition" . }}
{{- end }}

{{/*
  ======================================
  elcicd-kubernetes.role
  ======================================

  PARAMETERS LIST:
    . -> should always be root of chart
    $deployValues -> elCicd template for Role

  ======================================

  DEFAULT KEYS
  ---
    [spec]:
      aggregationRule
      rules

  ======================================

  el-CICD SUPPORTING TEMPLATES:
    "elcicd-common.apiObjectHeader"

  ======================================

  Defines a el-CICD template for a Kubernetes Role.
*/}}
{{- define "elcicd-kubernetes.role" }}
  {{- $ := get . "$" }}
  {{- $roleValues := get . "elCicdTemplate" }}

  {{- $_ := set $roleValues "kind" "Role" }}
  {{- include "elcicd-kubernetes.genericRoleDefinition" . }}
{{- end }}

{{/*
  ======================================
  elcicd-kubernetes.roleBinding
  ======================================

  PARAMETERS LIST:
    . -> should always be root of chart
    $deployValues -> elCicd template for RoleBinding

  ======================================

  DEFAULT KEYS
  ---
    [spec]:
      roleRef
      subjects

  ======================================

  el-CICD SUPPORTING TEMPLATES:
    "elcicd-common.apiObjectHeader"

  ======================================

  Defines a el-CICD template for a Kubernetes RoleBinding.
*/}}
{{- define "elcicd-kubernetes.roleBinding" }}
  {{- $ := get . "$" }}
  {{- $roleBindingValues := get . "elCicdTemplate" }}

  {{- $_ := set $roleBindingValues "kind" "RoleBinding" }}
  {{- include "elcicd-kubernetes.genericRoleBindingDefinition" . }}
{{- end }}
