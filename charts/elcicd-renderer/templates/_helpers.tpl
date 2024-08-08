# SPDX-License-Identifier: LGPL-2.1-or-later

{{/*
  ======================================
  elcicd-renderer.initElCicdRenderer
  ======================================

  PARAMETERS LIST:
    $ -> root of chart

  ======================================

  Initializes the el-CICD Renderer.

  1. Ensures all lists and dictionaries el-CICD Chart uses are non-null with default, empty collections.
  2. Merges global profiles ($.Values.global.elCicdProfiles) into the currently rendered chart's active profiles
     i. The chart will fail if elCicdProfiles is not a list type
  3. Gathers all defaults used in processing the chart.
  2. Initilizes some el-CICD chart internal data for processing purposes (elcicd-renderer.gatherElCicdDefaults)
  3. Sets the default, el-CICD template prefix.
    i. If not defined by the end user, assumes "elcicd-kubernetes"; i.e. if the templateName
       of a template is "bar", el-CICD Chart will assume the Helm template to call is "elcicd-kubernetes.bar"
  4. Defines internal el-CICD Chart values for parsing.
*/}}
{{- define "elcicd-renderer.initElCicdRenderer" }}
  {{- $ := . }}

  {{- $_ := set $.Values "global" ($.Values.global | default dict) }}

  {{- $_ := set $.Values "elCicdDefaults" ($.Values.elCicdDefaults | default dict) }}
  {{- $_ := set $.Values.elCicdDefaults "objName" ($.Values.elCicdDefaults.objName | default $.Release.Name) }}

  {{- $_ := set $.Values "elCicdDefs" ($.Values.elCicdDefs | default dict) }}
  {{- $_ := set $.Values "skippedTemplates" list }}

  {{- $_ := set $.Values.elCicdDefaults "templatesChart" ($.Values.elCicdDefaults.templatesChart | default "elcicd-kubernetes") }}

  {{- if or $.Values.elCicdProfiles $.Values.global.elCicdProfiles }}
    {{- $_ := set $.Values "elCicdProfiles" ($.Values.global.elCicdProfiles | default $.Values.elCicdProfiles | default list) }}
    {{- $_ := set $.Values "elCicdProfiles" (compact $.Values.elCicdProfiles) }}
    {{- if not (kindIs "slice" $.Values.elCicdProfiles) }}
      {{- fail (printf "Profiles must be specified as an array: %s" $.Values.elCicdProfiles) }}
    {{- end }}
  {{- end }}

  {{- include "elcicd-renderer.gatherElCicdDefaults" $ }}

  {{- range $dep := $.Chart.Dependencies }}
    {{- if (eq $dep.Name "elcicd-kubernetes") }}
      {{- include "elcicd-kubernetes.initElCicdDefaults" $ }}
    {{- end }}
  {{- end }}

  {{- include "elcicd-renderer.setInternalConstants" $ }}
{{- end }}

{{/*
  ======================================
  elcicd-renderer.setInternalConstants
  ======================================
*/}}
{{- define "elcicd-renderer.setInternalConstants" }}
  {{- $_ := set $.Values "__EC_EMPTY_LIST" list }}
  {{- $_ := set $.Values "__EC_EMPTY_DICT" list }}

  {{- $_ := set $.Values "__EC_RESULT_DICT" dict }}

  {{- $_ := set $.Values "__EC_DEPTH" "__EC_DEPTH" }}
  {{- $_ := set $.Values "__EC_MAX_DEPTH" 15 }}
  {{- $_ := set $.Values "__EC_ORIG_VALUE_KEY" "__EC_ORIG_VALUE_KEY" }}

  {{- $_ := set $.Values "__EC_FILE_PREFIX" "$<FILE|" }}
  {{- $_ := set $.Values "__EC_CONFIG_PREFIX" "$<CONFIG|" }}

  {{- $_ := set $.Values "__EC_ESCAPED_REGEX" "[\\\\][\\$][<]" }}
  {{- $_ := set $.Values "__EC_UNESCAPED_REGEX" "$<" }}
  {{- $_ := set $.Values "__EC_PARAM_REGEX" "(?:^|[^\\\\])\\$<([\\w]+?(?:[-][\\w]+?)*)>" }}

  {{- $_ := set $.Values "__EC_OBJNAME_REGEX" "[a-z0-9]([-a-z0-9]*[a-z0-9])?([.][a-z0-9]([-a-z0-9]*[a-z0-9])?)*" }}
  {{- $_ := set $.Values "__EC_PROFILE_REGEX" "[A-Z0-9]+(?:[._][A-Z0-9]+)*" }}
{{- end }}

{{/*
  ======================================
  elcicd-renderer.gatherElCicdDefaults
  ======================================

  PARAMETERS LIST:
    $ -> root of chart

  ======================================

  Collects the defaults el-CICD Chart will use when rendering.  Merges active profile
  specific defaults in.  Active profile maps of default are defined by

    elCicdDefaults-<profile>
*/}}
{{- define "elcicd-renderer.gatherElCicdDefaults" }}
  {{- $ := . }}

  {{- $_ := set $.Values "elCicdDefaults" ($.Values.elCicdDefaults | default dict) }}

  {{- range $profile := $.Values.elCicdProfiles }}
    {{- $profileDefaultsMap := (get $.Values (printf "elCicdDefaults-%s" $profile)) }}
    {{- if $profileDefaultsMap }}
      {{- $_ set $.Values "elCicdProfiles"  (mergeOverwrite $.Values.elCicdDefaults) }}
    {{- end }}
  {{- end }}
{{- end }}

{{/*
  ======================================
  elcicd-renderer.gatherElCicdTemplates
  ======================================

  PARAMETERS LIST:
    $ -> root of chart

  ======================================

  Collects all lists of the form "elCicdTemplates-*" from .Values and appends them to the elCicdTemplates list, and
  then confirms the elCicdTemplates list is not empty.  The chart will be failed if the elCicdTemplates list is empty.
*/}}
{{- define "elcicd-renderer.gatherElCicdTemplates" }}
  {{- $ := . }}

  {{- if $.Values.elCicdTemplates }}
    {{- if (not (kindIs "slice" $.Values.elCicdTemplates)) }}
        {{- fail "elcicd-renderer elCicdTemplates: must be defined" }}
    {{- end }}
  {{- end }}

  {{- range $key, $value := $.Values }}
    {{- if hasPrefix "elCicdTemplates-" $key }}
      {{- if $.Values.elCicdTemplates }}
        {{- $_ := set $.Values "elCicdTemplates" (concat $.Values.elCicdTemplates $value) }}
      {{- else }}
        {{- $_ := set $.Values "elCicdTemplates" $value }}
      {{- end }}
    {{- end }}
  {{- end }}

  {{- $_ := required "Missing elCicdTemplates: list" $.Values.elCicdTemplates }}
{{- end }}


{{/*
  ======================================
  elcicd-renderer.filterTemplates
  ======================================

  el-CICD Chart templates may be condigured to only render or not render depending on the active profile(s).

  elCicdTemplates:
  - templateName: <template name>
    objName: <object name>
    mustHaveAnyProfile: <render if the active profile is list>
    mustNotHaveAnyProfile: <do NOT render if the active profile is list>
    mustHaveEveryProfile: <render only every profiles in list is active>
    mustHaveEveryProfile: <do NOT render only every profiles in list is active>

  Skipped templates will be listed when the Chart has completed rendering.
*/}}
{{- define "elcicd-renderer.filterTemplates" }}
  {{- $ := index . 0 }}
  {{- $templates := index . 1 }}

  {{- $_ := set $.Values "elCicdProfiles" ($.Values.elCicdProfiles | default list) }}

  {{- $renderList := list }}
  {{- $skippedList := list }}
  {{- $resultKey := uuidv4 }}
  {{- range $template := $templates }}
    {{- include "elcicd-renderer.processFilteringLists" (list $ $template $resultKey) }}

    {{- $hasMatchingProfile := not $template.mustHaveAnyProfile }}
    {{- range $profile := $template.mustHaveAnyProfile }}
      {{- $hasMatchingProfile = or $hasMatchingProfile (has $profile $.Values.elCicdProfiles) }}
    {{- end }}

    {{- $hasNoProhibitedProfiles := not $template.mustNotHaveAnyProfile }}
    {{- range $profile := $template.mustNotHaveAnyProfile }}
      {{- $hasNoProhibitedProfiles = or $hasNoProhibitedProfiles (has $profile $.Values.elCicdProfiles) }}
    {{- end }}
    {{- $hasNoProhibitedProfiles = or (not $template.mustNotHaveAnyProfile) (not $hasNoProhibitedProfiles) }}

    {{- $hasAllRequiredProfiles := true }}
    {{- range $profile := $template.mustHaveEveryProfile }}
      {{- $hasAllRequiredProfiles = and $hasAllRequiredProfiles (has $profile $.Values.elCicdProfiles) }}
    {{- end }}

    {{- $doesNotHaveAllProhibitedProfiles := true }}
    {{- range $profile := $template.mustNotHaveEveryProfile }}
      {{- $doesNotHaveAllProhibitedProfiles = and $doesNotHaveAllProhibitedProfiles (has $profile $.Values.elCicdProfiles) }}
    {{- end }}
    {{- $doesNotHaveAllProhibitedProfiles = or (not $template.doesNotHaveAllProhibitedProfiles) (not $doesNotHaveAllProhibitedProfiles) }}

    {{- if and $hasMatchingProfile $hasNoProhibitedProfiles $hasAllRequiredProfiles $doesNotHaveAllProhibitedProfiles  }}
      {{- $renderList = append $renderList $template }}
    {{- else }}
      {{- $objName := (empty $template.objNames | ternary (print "objName: " $template.objName) (print "objNames: " $template.objNames)) }}
      {{- $skippedList = append $skippedList (list $template.templateName $objName) }}
    {{- end }}
  {{- end }}

  {{- $_ := set $.Values "renderingTemplates" $renderList }}
  {{- $_ := set $.Values "skippedTemplates" $skippedList }}
{{- end }}

{{- define "elcicd-renderer.processFilteringLists" }}
  {{- $ := index . 0 }}
  {{- $template := index . 1 }}
  {{- $resultKey := index . 2 }}

  {{- $_ := set $template "mustHaveAnyProfile" ($template.mustHaveAnyProfile | default list) }}
  {{- include "elcicd-renderer.processValue" (list $ $template.mustHaveAnyProfile $.Values.elCicdDefs list $resultKey) }}
  {{- $_ := set $template "mustHaveAnyProfile" (get $.Values.__EC_RESULT_DICT $resultKey) }}
  {{- $_ := unset $.Values.__EC_RESULT_DICT $resultKey }}

  {{- $_ := set $template "mustNotHaveAnyProfile" ($template.mustNotHaveAnyProfile | default list) }}
  {{- include "elcicd-renderer.processValue" (list $ $template.mustNotHaveAnyProfile $.Values.elCicdDefs list $resultKey) }}
  {{- $_ := set $template "mustNotHaveAnyProfile" (get $.Values.__EC_RESULT_DICT $resultKey) }}
  {{- $_ := unset $.Values.__EC_RESULT_DICT $resultKey }}

  {{- $_ := set $template "mustHaveEveryProfile" ($template.mustHaveEveryProfile | default list) }}
  {{- include "elcicd-renderer.processValue" (list $ $template.mustHaveEveryProfile $.Values.elCicdDefs list $resultKey) }}
  {{- $_ := set $template "mustHaveEveryProfile" (get $.Values.__EC_RESULT_DICT $resultKey) }}
  {{- $_ := unset $.Values.__EC_RESULT_DICT $resultKey }}

  {{- $_ := set $template "mustNotHaveEveryProfile" ($template.mustNotHaveEveryProfile | default list) }}
  {{- include "elcicd-renderer.processValue" (list $ $template.mustNotHaveEveryProfile $.Values.elCicdDefs list $resultKey) }}
  {{- $_ := set $template "mustNotHaveEveryProfile" (get $.Values.__EC_RESULT_DICT $resultKey) }}
  {{- $_ := unset $.Values.__EC_RESULT_DICT $resultKey }}
{{- end }}

