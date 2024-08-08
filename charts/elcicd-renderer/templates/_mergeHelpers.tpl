# SPDX-License-Identifier: LGPL-2.1-or-later

{{/*
  ======================================
  elcicd-renderer.mergeElCicdDefs
  ======================================

  PARAMETERS LIST:
    $ -> root of chart
    $elCicdDefsMap -> src map of el-CICD variable definitions
    $destElCicdDefs -> map in which results are merged into
    $baseObjName -> base objName, from the templates list of objNames if defined
    $objName -> objName of template

  ======================================

  Merges all elCicdDefs dictionaries based on profiles and object names to create a
  dictionary of variable definitions that will be used before finally rendering the el-CICD template.
  This template is called thre times for the overall chart.  The first time for some basic pre-processing
  of minimal template data such as profiles.  The next two times are for processing the templates for el-CICD
  variable references. First to merge all elCicdDefs defined directly under the .Values object, and then for
  each template specific variable definitions.

  Order of precedence in ascending order:

    1. elCicdDefsMap
       i. Parent map that contains all elCicdDef maps for merging.
          a. If merging variable definitions a the top level, this will be a copy of .Values.elCicdDefs
          b. If merging variable definitions for a template, this will be a copy of the fully merged, top level elCicdDefs map.
    2. elCicdDefs-<profile>
       i. Following Helm standard, in order of listed profiles first to last
    3. elCicdDefs-<baseObjName>
       i. baseObjName is the raw name from the objNames list before modification
    4. elCicdDefs-<objName>
       i. objName is the final, processed name of the resource being generated from the objNames list
    5. elCicdDefs-<baseObjName>-<profile>
       i. Same as elCicdDefs-<baseObjName>, but only for a specific profile, in first to last order of the profiles list
    6. elCicdDefs-<objName>-<profile>
       i. Same as elCicdDefs-<objName>, but only for a specific profile, in first to last order of the profiles list

    Merged results are contained in destElCicdDefs.
*/}}
{{- define "elcicd-renderer.mergeElCicdDefs" }}
  {{- $ := index . 0 }}
  {{- $elCicdDefsMap := index . 1 }}
  {{- $destElCicdDefs := index . 2 }}
  {{- $baseObjName := index . 3 }}
  {{- $objName := index . 4 }}

  {{- range $profile := $.Values.elCicdProfiles }}
    {{- if not (regexMatch $.Values.__EC_PROFILE_REGEX $profile) }}
      {{- fail (printf "profile \"%s\" does match regex naming requirements, \"%s\"" $profile $.Values.__EC_PROFILE_REGEX) }}
    {{- end }}
    {{- $profileDefs := get $elCicdDefsMap (printf "elCicdDefs|%s" $profile) }}
    {{- include "elcicd-renderer.deepCopyDict" (list $profileDefs $destElCicdDefs) }}
  {{- end }}

  {{- if ne $baseObjName $objName }}
    {{- $baseObjNameDefs := get $elCicdDefsMap (printf "elCicdDefs|%s" $baseObjName) }}
    {{- include "elcicd-renderer.deepCopyDict" (list $baseObjNameDefs $destElCicdDefs) }}
  {{- end }}

  {{- if $objName }}
    {{- $objNameDefs := get $elCicdDefsMap (printf "elCicdDefs|%s" $objName) }}
    {{- include "elcicd-renderer.deepCopyDict" (list $objNameDefs $destElCicdDefs) }}
  {{- end }}

  {{- range $profile := $elCicdDefsMap.elCicdProfiles }}
    {{- if ne $baseObjName $objName }}
      {{- $baseObjNameDefs := get $elCicdDefsMap (printf "elCicdDefs|%s|%s" $profile $baseObjName) }}
      {{- include "elcicd-renderer.deepCopyDict" (list $baseObjNameDefs $destElCicdDefs) }}

      {{- $baseObjNameDefs := get $elCicdDefsMap (printf "elCicdDefs|%s|%s" $baseObjName $profile) }}
      {{- include "elcicd-renderer.deepCopyDict" (list $baseObjNameDefs $destElCicdDefs) }}
    {{- end }}

    {{- if $objName }}
      {{- $objNameDefs := get $elCicdDefsMap (printf "elCicdDefs|%s|%s" $profile $objName) }}
      {{- include "elcicd-renderer.deepCopyDict" (list $objNameDefs $destElCicdDefs) }}

      {{- $objNameDefs := get $elCicdDefsMap (printf "elCicdDefs|%s|%s" $objName $profile) }}
      {{- include "elcicd-renderer.deepCopyDict" (list $objNameDefs $destElCicdDefs) }}
    {{- end }}
  {{- end }}
{{- end }}

{{/*
  ======================================
  elcicd-renderer.deepCopyDict
  ======================================

  PARAMETERS LIST:
    $srcDict -> map to copy
    $destDict -> map to copy srcDict into

  ======================================

  Recursively copies all keys and values of a source dictionary into a destination dictionary; i.e. all maps
  contained in the source map and any of its values are copies of the original.  String and lists do not need
  to be copied, since they are immutable.
  
  NOTE: This template was created because of potential anamolies with Helm's deepcopy.  Will need to revisit in the future.
*/}}
{{- define "elcicd-renderer.deepCopyDict" }}
  {{- $srcDict := index . 0 }}
  {{- $destDict := index . 1 }}

  {{- if $srcDict }}
    {{- range $key, $value := $srcDict }}
      {{- if (kindIs "map" $value) }}
        {{- $newValue := dict }}
        {{- include "elcicd-renderer.deepCopyDict" (list $value $newValue) }}
        {{- $value = $newValue }}
      {{- end }}
      {{- $_ := set $destDict $key ($value | default "") }}
    {{- end }}
  {{- end }}
{{- end }}