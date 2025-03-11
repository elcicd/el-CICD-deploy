{{/*
  Defines templates for rendering Kubernetes workload resources, including:
  - ResourceQuota
  - LimitRange

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
  elcicd-kubernetes.resourceQuota
  ======================================

  PARAMETERS LIST:
    . -> should always be root of chart
    $quotaValues -> elCicd template for ResourceQuota

  ======================================

  DEFAULT KEYS
  ---
  [spec]:
    hard
    scopeSelector
    scopes

  ======================================

  el-CICD SUPPORTING TEMPLATES:
    "elcicd-common.apiObjectHeader"

  ======================================

  Defines a el-CICD template for a Kubernetes ResourceQuota.
*/}}
{{- define "elcicd-kubernetes.resourceQuota" }}
  {{- $ := get . "$" }}
  {{- $quotaValues := get . "elCicdTemplate" }}

  {{- $_ := set $quotaValues "kind" "ResourceQuota" }}
  {{- include "elcicd-common.apiObjectHeader" . }}
spec:
  {{- $whiteList := list "hard"
                         "scopeSelector"
                         "scopes"	}}
  {{- include "elcicd-common.outputToYaml" (dict "$" $ "elCicdTemplate" $quotaValues "whiteList" $whiteList) }}
{{- end }}

{{/*
  ======================================
  elcicd-kubernetes.limitRange
  ======================================

  PARAMETERS LIST:
    . -> should always be root of chart
    $limitValues -> elCicd template for LimitRange

  ======================================

  DEFAULT KEYS
  ---
    [spec]:
      limits

  ======================================

  el-CICD SUPPORTING TEMPLATES:
    "elcicd-common.apiObjectHeader"

  ======================================

  Defines a el-CICD template for a Kubernetes LimitRange.
*/}}
{{- define "elcicd-kubernetes.limitRange" }}
  {{- $ := get . "$" }}
  {{- $limitValues := get . "elCicdTemplate" }}

  {{- $_ := set $limitValues "kind" "LimitRange" }}
  {{- include "elcicd-common.apiObjectHeader" . }}
spec:
  {{- $whiteList := list "limits"	}}
  {{- include "elcicd-common.outputToYaml" (dict "$" $ "elCicdTemplate" $limitValues "whiteList" $whiteList) }}
{{- end }}