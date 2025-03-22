{{/*
  Defines templates for rendering Kubernetes workload resources, including:
  - Namespace
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
  elcicd-kubernetes.namespace
  ======================================

  PARAMETERS LIST:
    . -> should always be root of chart
    $nsValues -> elCicd template for Namespace

  ======================================

  el-CICD SUPPORTING TEMPLATES:
    "elcicd-common.apiObjectHeader"

  ======================================

  Defines a el-CICD template for a Kubernetes Namespace.
*/}}
{{- define "elcicd-kubernetes.namespace" }}
  {{- $ := get . "$" }}
  {{- $nsValues := .elCicdTemplate }}

  {{- $_ := set $nsValues "kind" "Namespace" }}
  {{- include "elcicd-common.apiObjectHeader" . }}
{{- end }}