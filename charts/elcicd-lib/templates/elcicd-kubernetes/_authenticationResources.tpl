{{/*
  ======================================
  elcicd-kubernetes.serviceAccount
  ======================================

  PARAMETERS LIST:
    . -> should always be root of chart
    $deployValues -> elCicd template for ServiceAccount

  ======================================

  HELPER KEYS
  ---
    imagePullSecrets:
    - [name]:
    secrets:
    - [name]:
  

  ======================================

  DEFAULT KEYS
  ---
    automountServiceAccountToken

  ======================================

  el-CICD SUPPORTING TEMPLATES:
    "elcicd-common.apiObjectHeader"

  ======================================

  Defines a el-CICD template for a Kubernetes ServiceAccount.
*/}}
{{- define "elcicd-kubernetes.serviceAccount" }}
{{- $args := . }}
{{- $ := get $args "$" }}
{{- $svcAcctValues := get $args "elCicdTemplate" }}

{{- $_ := set $svcAcctValues "kind" "ServiceAccount" }}
{{- include "elcicd-common.apiObjectHeader" . }}
{{- $whiteList := list "automountServiceAccountToken"	}}
{{- include "elcicd-common.outputToYaml" (list $ $svcAcctValues $whiteList) }}
{{- if $svcAcctValues.imagePullSecrets }}
imagePullSecrets:
{{- range $imagePullSecret := $svcAcctValues.imagePullSecrets  }}
- name: {{ $imagePullSecret }}
{{- end }}
{{- end }}
{{- if $svcAcctValues.secrets }}
secrets:
{{- range $secret := $svcAcctValues.secrets  }}
- name: {{ $secret }}
{{- end }}
{{- end }}
{{- end }}
