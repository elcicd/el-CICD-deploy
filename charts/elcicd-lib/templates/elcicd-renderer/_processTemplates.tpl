# SPDX-License-Identifier: LGPL-2.1-or-later

{{/*
  ======================================
  elcicd-renderer.generateAllTemplates
  ======================================

  PARAMETERS LIST:
    $ -> root of chart
    $templates -> list of elCicdTemplates defined in *values.yaml

  ======================================

  Generates the complete list of el-CICD templates to be rendered based on each template's optional objNames
  and namespaces lists.  objNames are processed first, and namespaces afterwards.

  The final list of templates to be rendered is set to $.Values.allTemplates
*/}}
{{- define "elcicd-renderer.generateAllTemplates" }}
  {{- $ := get . "$" }}
  {{- $templates := .elCicdTemplates }}

  {{- $allTemplates := list }}
  {{- $resultKey := uuidv4 }}
  {{- range $template := $templates }}
    {{- if $template.objName }}
      {{- if eq $template.objName "$<OBJ_NAME>" }}
        {{- $failMsgTpl := "templateName %s objName: $<OBJ_NAME>: OBJ_NAME IS RESERVED; use different variable name or elCicdDefaults.objName" }}
        {{- fail (printf $failMsgTpl $template.templateName) }}
      {{- end }}
    {{- end }}

    {{- include "elcicd-renderer.processModularTemplate" (dict "$" $ "elCicdTemplate" $template "resultKey" $resultKey) }}
    {{- $modularTemplates := get $.Values.__EC_RESULT_DICT $resultKey }}
    {{- $_ := unset $.Values.__EC_RESULT_DICT $resultKey }}

    {{- $objNameTemplates := list }}
    {{- range $modularTemplate := $modularTemplates }}
      {{- include "elcicd-renderer.processMatrixKey"
                  (dict "$" $
                         "elCicdTemplate" $modularTemplate
                         "matrixKey" "objNames"
                         "templateKey" "objName"
                         "defaultValue" $.Values.elCicdDefaults.objName
                         "elCicdDefs" $.Values.elCicdDefs
                         "resultKey" $resultKey) }}
      {{- $objNameTemplates = concat $objNameTemplates (get $.Values.__EC_RESULT_DICT $resultKey) }}
      {{- $_ := unset $.Values.__EC_RESULT_DICT $resultKey }}
    {{- end }}

    {{- range $objNameTemplate := $objNameTemplates }}
      {{- include "elcicd-renderer.processMatrixKey"
                  (dict "$" $
                         "elCicdTemplate" $objNameTemplate
                         "matrixKey" "namespaces"
                         "templateKey" "namespace"
                         "defaultValue" $.Release.Namespace
                         "elCicdDefs" $.Values.elCicdDefs
                         "resultKey" $resultKey) }}
      {{- $allTemplates = concat $allTemplates (get $.Values.__EC_RESULT_DICT $resultKey) }}
      {{- $_ := unset $.Values.__EC_RESULT_DICT $resultKey }}
    {{- end }}
  {{- end }}

  {{- $_ := set $.Values "allTemplates" $allTemplates }}
{{- end }}

{{/*
  ======================================
  elcicd-renderer.processModularTemplate
  ======================================

  PARAMETERS LIST:
    $ -> root of chart
    $template -> template defined in *values.yaml to be processed
    $resultKey -> key used to store and retrieve results from the el-CICD Chart result dictionary

  ======================================

  If a templateName is a list of templates, generates an individual template for member of the list.
  */}}
{{ define "elcicd-renderer.processModularTemplate" }}
  {{- $ := get . "$" }}
  {{- $template := .elCicdTemplate }}
  {{- $resultKey := .resultKey }}

  {{- $modularTemplates := list }}
  {{- range $newTemplateName := $template.templateNames }}
    {{- $newTemplate := deepCopy $template }}
    {{- $_ := set $newTemplate "templateName" $newTemplateName }}
    {{- $modularTemplates = append $modularTemplates $newTemplate }}
  {{- end }}

  {{- if not $modularTemplates }}
    {{- if or (not $template.templateName) (kindIs "string" $template.templateName) }}
      {{- $modularTemplates = append $modularTemplates $template }}
    {{- else }}
      {{- fail (printf "Bad templateName value { %s }: must be empty or string" $template.templateName) }}
    {{- end }}
  {{- end }}

  {{- $_ := set $.Values.__EC_RESULT_DICT $resultKey $modularTemplates }}
{{- end }}

{{/*
  ======================================
  elcicd-renderer.processMatrixKey
  ======================================

  PARAMETERS LIST:
    $ -> root of chart
    $template -> template defined in *values.yaml to be processed
    $matrixKey -> list of values to process
    $templateKey -> key of new template processed value will be placed
    $elCicdDefs -> final chart level elCicdDefs
    $resultKey -> key used to store and retrieve results from the el-CICD Chart result dictionary

  ======================================


  First evaluate the namespaces value for any el-CICD variables and dereference them.  Only chart-level variable definitions will be
  considered.  Next, generate a copy of the template per value in the list and append and add to the list of templates to render.

  If the namespace key has a value with $<> in it, it will be replaced with the baseObjName (i.e the value in the namespaces list).
  If the namespace key has a value with $<#> in it, it will be replaced with the index of baseObjName in the namespaces list.
*/}}
{{- define "elcicd-renderer.processMatrixKey" }}
  {{- $ := get . "$" }}
  {{- $template := .elCicdTemplate }}
  {{- $matrixKey := .matrixKey }}
  {{- $templateKey := .templateKey }}
  {{- $defaultValue := .defaultValue }}
  {{- $elCicdDefs := .elCicdDefs }}
  {{- $resultKey := .resultKey }}

  {{- $matrixTemplates := list }}
  {{- $matrix := get $template $matrixKey }}
  {{- if $matrix }}
    {{- include "elcicd-renderer.processTemplateMatrixValue" (dict "$" $ "elCicdTemplate" $template "matrixKey" $matrixKey) }}
    {{- $matrix := get $template $matrixKey }}

    {{- include "elcicd-renderer.generateTemplateMatrixValues" (dict "$" $ "elCicdTemplate" $template "matrixKey" $matrixKey) }}
    {{- $matrix := get $template $matrixKey }}

    {{- range $index, $matrixValue := $matrix }}
      {{- $baseMatrixValue := $matrixValue }}

      {{- $matrixValue = replace "$<>" $matrixValue (get $template $templateKey | default $baseMatrixValue) }}
      {{- $matrixValue = replace "$<#>" (add1 $index | toString) $matrixValue }}

      {{- $newTemplate := deepCopy $template }}
      {{- $_ := set $newTemplate $templateKey $matrixValue }}
      {{- $baseTemplateKey := printf "base%s" (title $templateKey) }}
      {{- $_ := set $newTemplate $baseTemplateKey $baseMatrixValue }}

      {{- $matrixTemplates = append $matrixTemplates $newTemplate }}
    {{- end }}
  {{- else }}
    {{- $_ := set $template $templateKey ((get $template $templateKey) | default $defaultValue) }}

    {{- $matrixTemplates = list $template }}
  {{- end }}

  {{- $_ := set $.Values.__EC_RESULT_DICT $resultKey $matrixTemplates }}
{{- end }}

{{/*
  ======================================
  elcicd-renderer.processTemplateMatrixValue
  ======================================

  PARAMETERS LIST:
    $ -> root of chart
    $template -> template to operate on.
    $matrixKey -> currently only "namespaces" or "objNames" is supported

  ======================================

  Dereferences any el-CICD variables references in a matrices list; e.g. the objNames or namespaces list.
*/}}
{{- define "elcicd-renderer.processTemplateMatrixValue" }}
  {{- $ := get . "$" }}
  {{- $template := .elCicdTemplate }}
  {{- $matrixKey := .matrixKey }}

  {{- $generatorVal := get $template $matrixKey }}

  {{- $resultKey := uuidv4 }}
  {{- include "elcicd-renderer.processValue"
              (dict "$" $ "value" $generatorVal "elCicdDefs" $.Values.elCicdDefs "processedVarsList" list "resultKey" $resultKey) }}
  {{- $generatorVal := (get $.Values.__EC_RESULT_DICT $resultKey) | default list }}
  {{- if $generatorVal }}
    {{- if not (kindIs "slice" $generatorVal) }}
      {{- fail (printf "%s must evaluate to nil or a list: %s" $matrixKey (get $template $matrixKey)) }}
    {{- end }}
  {{- end }}
  {{- $_ := unset $.Values.__EC_RESULT_DICT $resultKey }}

  {{- $_ := set $template $matrixKey $generatorVal }}
{{- end }}

{{/*
  ======================================
  elcicd-renderer.generateTemplateMatrixValues
  ======================================

  PARAMETERS LIST:
    $ -> root of chart
    $template -> template to operate on.
    $matrixKey -> currently only "namespaces" or "objNames" is supported

  ======================================

  Generates multiple entries if specified.
*/}}
{{- define "elcicd-renderer.generateTemplateMatrixValues" }}
  {{- $ := get . "$" }}
  {{- $template := .elCicdTemplate }}
  {{- $matrixKey := .matrixKey }}

  {{- $matrix := get $template $matrixKey }}

  {{- $fullMatrix := list }}
  {{- range $index, $matrixValue := $matrix }}
    {{- if $matrixValue }}
      {{- if (kindIs "map" $matrixValue) }}
        {{- $pattern := (get $matrixValue "pattern") }}
        {{- $matrixValue = unset $matrixValue "pattern" }}
        {{- $key := (first (keys $matrixValue)) | default "" }}
        {{ range $index := until (int (get $matrixValue $key | default 0)) }}
          {{- $newKey := $key }}
          {{- if $pattern }}
            {{- $newKey = replace "$<>" $key $pattern }}
            {{- $newKey = replace "$<#>" (add1 $index | toString) $newKey }}
          {{- end }}
          {{- $fullMatrix = append $fullMatrix $newKey }}
        {{- end }}
      {{- else }}
        {{- $fullMatrix = append $fullMatrix $matrixValue }}
      {{- end }}
    {{- end }}
  {{- end }}

  {{- $_ := set $template $matrixKey $fullMatrix }}
{{- end }}

{{/*
  ======================================
  elcicd-renderer.processTemplates
  ======================================

  PARAMETERS LIST:
    $ -> root of chart
    $templates -> list of elCicdTemplates defined in *values.yaml

  ======================================

  Process all el-CICD templates in the template list before rendering.  This means realizing the final
  elCicdDefs for ht

  Process a template has the following steps:

  1. Process all **chart's** el-CICD variable definition maps of the form elCicdDefs-*  (i.e. all .Values.elCicdDefs-*)
     for el-CICD variables using the **chart's** elCicdDefs map (i.e. .Values.elCicdDefs).
     (elcicd-renderer.preProcessElCicdDefsMapNames)

  For each template to be rendered:

  1. Copy the .Values.elCicdDefs into $tplElCicdDefs (template specific variable defintions). (elcicd-renderer.deepCopyDict)
  2. Copy the $template.elCicdDefs onto $tplElCicdDefs (elcicd-renderer.deepCopyDict)
  3. Process all **template's** el-CICD variable definition maps of the form elCicdDefs-*  (i.e. all $template.elCicdDefs-*)
     for el-CICD variables using the **template's** elCicdDefs map (i.e. $template.elCicdDefs).
     (elcicd-renderer.preProcessElCicdDefsMapNames)
  4. Merge the different **chart's** elCicdDefs-<baseObjName>-<profile> maps into the $tplElCicdDefs. (elcicd-renderer.mergeElCicdDefs)
  5. Merge the different **templates's** elCicdDefs-<baseObjName>-<profile> maps into the $tplElCicdDefs. (elcicd-renderer.mergeElCicdDefs)
  6. Load any file variable references into the variable values (elcicd-renderer.preProcessFilesAndConfig); e.g.
     elCicdDefs:
      SOME_VAR: $<FILE|file-to-be-loaded.ext> -> loads file-to-be-loaded.ext as text into as the value of SOME_VAR
      SOME_VAR: $<CONFIG|file-to-be-loaded> -> loads an env/properties/conf line delimited file of key/values pairs
                defined by key=value as a map and assigns to the variable SOME_VAR
  7. Sets default/el-CICD built-in values to the template elCicdDefs including:
     - EL_CICD_DEPLOYMENT_TIME_NUM - time of deployment in nanoseconds
     - EL_CICD_DEPLOYMENT_TIME - human readable date and time
     - BASE_OBJ_NAME - value the objName was derived from if defined
     - OBJ_NAME - name of template; typically translates to metadata.name
     - BASE_NAME_SPACE - value the namespace was derived from if defined
     - NAME_SPACE - namespace the template is being deployed to
     - HELM_RELEASE_NAME - .Release.Name
     - HELM_RELEASE_NAMESPACE - .Release.Namespace
     NOTE: templates that do not have or use namespaces can safely ignore those values.
  8. Adds the el-CICD defaults to the template.
  9. Recursively walks the template realizing the values of all el-CICD variable references in
     keys or values.
     NOTE: variables that realized as empty keys or empty **string** values will be removed from
           the template.
 10. For debugging/documentation purposes, $tplElCicdDefs is added to the template.
*/}}
{{- define "elcicd-renderer.processTemplates" }}
  {{- $ := get . "$" }}
  {{- $templates := .elCicdTemplates }}

  {{- range $template := $templates }}
    {{- $tplElCicdDefs := dict }}
    {{- include "elcicd-renderer.deepCopyDict" (dict "srcDict" $.Values.elCicdDefs "destDict" $tplElCicdDefs) }}
    {{- include "elcicd-renderer.deepCopyDict" (dict "srcDict" $template.elCicdDefs "destDict" $tplElCicdDefs) }}

    {{- $args := dict "$" $ "parentMap" $template "elCicdDefs" $tplElCicdDefs }}
    {{- include "elcicd-renderer.preProcessElCicdDefsMapNames" $args }}

    {{- $args := dict "$" $ 
                      "elCicdDefsMap" $.Values
                      "destElCicdDefs" $tplElCicdDefs
                      "baseObjName" $template.baseObjName
                      "objName" $template.objName }}
    {{- include "elcicd-renderer.mergeElCicdDefs" $args }}
    {{- $_ := set $args "elCicdDefsMap" $template }}
    {{- include "elcicd-renderer.mergeElCicdDefs" $args }}
    {{- include "elcicd-renderer.preProcessFilesAndConfig" (dict "$" $ "elCicdDefs" $tplElCicdDefs) }}

    {{- include "elcicd-renderer.setBuiltInTplElCicdDefsValues" (dict "$" $ "elCicdTemplate" $template "tplElCicdDefs" $tplElCicdDefs ) }}

    {{- $_ := set $template "elCicdDefaults" dict }}
    {{- include "elcicd-renderer.deepCopyDict" (dict "srcDict" $.Values.elCicdDefaults "destDict" $template.elCicdDefaults) }}

    {{- include "elcicd-renderer.replaceVarRefsInMap"
                (dict "$" $ "map" $template "elCicdDefs" $tplElCicdDefs "processedVarsList" list) }}
    {{- if and ($template.objName) (not (regexMatch $.Values.__EC_OBJNAME_REGEX $template.objName)) }}
      {{- fail (printf "objName \"%s\" does match regex naming requirements , \"%s\"" $template.objName $.Values.__EC_OBJNAME_REGEX) }}
    {{- end }}

    {{- $_ := set $template "tplElCicdDefs" $tplElCicdDefs }}
  {{- end }}
{{- end }}

{{- define "elcicd-renderer.setBuiltInTplElCicdDefsValues" }}
  {{- $ := get . "$" }}
  {{- $template := .elCicdTemplate }}
  {{- $tplElCicdDefs := .tplElCicdDefs }}

  {{- $_ := set $tplElCicdDefs "EL_CICD_DEPLOYMENT_TIME_NUM" $.Values.__EC_DEPLOYMENT_TIME_NUM }}
  {{- $_ := set $tplElCicdDefs "EL_CICD_DEPLOYMENT_TIME" $.Values.__EC_DEPLOYMENT_TIME }}

  {{- $_ := set $tplElCicdDefs "BASE_OBJ_NAME" ($template.baseObjName | default $template.objName) }}
  {{- $_ := set $tplElCicdDefs "OBJ_NAME" $template.objName }}

  {{- $_ := set $tplElCicdDefs "NAME_SPACE" ($template.namespace| default $.Release.Namespace) }}
  {{- $_ := set $tplElCicdDefs "BASE_NAME_SPACE" ($template.baseNamespace | default $tplElCicdDefs.NAME_SPACE) }}

  {{- $_ := set $tplElCicdDefs "HELM_RELEASE_NAME" $.Release.Name }}
  {{- $_ := set $tplElCicdDefs "HELM_RELEASE_NAMESPACE" $.Release.Namespace }}
{{- end }}

{{/*
  ======================================
  elcicd-renderer.processTemplates
  ======================================

  PARAMETERS LIST:
    $ -> root of chart
    $parentMap -> map containing all elCicdDefs
    $elCicdDefs -> el-CICD variable defintiions

  ======================================

  Preprocess all elCicdDefs-* maps for el-CICD variables; e.g.:

    elCicdDefs:
      SOME_VAR: some-obj-name

    elCicdDefs-$<SOME_VAR>:
      VAR_DEF: var-def

  result in:

    elCicdDefs-some-obj-name:
      VAR_DEF: var-def

  And VAR_DEF will be defined for use for any template with the objName "some-obj-name".  Chart level el-CICD maps will
  only use the base elCicdDefs map for processing.  Each template will be evaluated will a map derived from all el-CICD
  variable definitions NOT of the form elCicdDefs-* ATTACHED DIRECTLY TO THE TEMPLATE.
  */}}
{{- define "elcicd-renderer.preProcessElCicdDefsMapNames" }}
  {{- $ := get . "$" }}
  {{- $parentMap := .parentMap }}
  {{- $elCicdDefs := .elCicdDefs }}

  {{- $resultKey := uuidv4 }}
  {{- range $key, $value := $parentMap }}
    {{- if hasPrefix "elCicdDefs-" $key }}
      {{- include "elcicd-renderer.replaceRefsInMapKey"
                  (dict "$" $ "map" $parentMap "key" $key "elCicdDefs" $elCicdDefs "resultKey" $resultKey) }}
    {{- end }}
  {{- end }}
{{- end }}

{{/*
  ======================================
  elcicd-renderer.replaceVarRefsInMap
  ======================================

  PARAMETERS LIST:
    $ -> root of chart
    $map -> the map to process for el-CICD variable references
    $elCicdDefs -> el-CICD variable defintiions
    $processedVarsList -> list of variables tracked for debugging purposes

  ======================================

  Walk the given dictionary and replace any el-CICD variable references with their values.  Each value will be processed.
  If the value is an non-empty string, map, or slice then process the key for el-CICD variables; otherwise, remove the
  key/value pair.

  This template is always the start of processing for an el-CICD template.  All el-CICD templates are defined as a map in
  a list of el-CICD templates.
*/}}
{{- define "elcicd-renderer.replaceVarRefsInMap" }}
  {{- $ := index . "$" }}
  {{- $map := .map }}
  {{- $elCicdDefs := .elCicdDefs }}
  {{- $processedVarsList := index . "processedVarsList" }}

  {{- $resultKey := uuidv4 }}
  {{- range $key, $value := $map }}
    {{- include "elcicd-renderer.processValue"
                (dict "$" $ "value" $value "elCicdDefs" $elCicdDefs "processedVarsList" $processedVarsList "resultKey" $resultKey) }}
    {{- $newValue := get $.Values.__EC_RESULT_DICT $resultKey }}
    {{- $_ := unset $.Values.__EC_RESULT_DICT $resultKey }}

    {{- if and (not (and (kindIs "string" $newValue) (empty $newValue))) (not (eq (typeOf $newValue) "<nil>")) }}
      {{- $_ := set $map $key $newValue }}
      {{- include "elcicd-renderer.replaceRefsInMapKey" (dict "$" $ "map" $map "key" $key "elCicdDefs" $elCicdDefs "resultKey" $resultKey) }}
    {{- else }}
      {{- $_ := unset $map $key }}
    {{- end }}
  {{- end }}
{{- end }}

{{/*
  ======================================
  elcicd-renderer.replaceRefsInMapKey
  ======================================

  PARAMETERS LIST:
    $ -> root of chart
    $map -> the map being processed for el-CICD variable references
    $key -> the key to evaluate for el-CICD variable references
    $elCicdDefs -> el-CICD variable definitions
    $resultKey -> key used to store and retrieve results from the el-CICD Chart result dictionary

  ======================================

  Walk the given dictionary and replace any el-CICD variable references with their values.  Each value will be processed.
  If the value is an empty string, remove the key/value pair; otherwise, process the key for el-CICD variables.  If the key
  is an empty string, remove the key/value pair.  Note that keys MUST resolve to strings, or an error will be raised by Helm.
*/}}
{{- define "elcicd-renderer.replaceRefsInMapKey" }}
  {{- $ := get . "$" }}
  {{- $map := .map }}
  {{- $key := .key }}
  {{- $elCicdDefs := .elCicdDefs }}
  {{- $resultKey := .resultKey }}

  {{- $value := get $map $key }}

  {{- include "elcicd-renderer.processValue"
              (dict "$" $ "value" $key "elCicdDefs" $elCicdDefs "processedVarsList" list "resultKey" $resultKey) }}
  {{- $newKey := get $.Values.__EC_RESULT_DICT $resultKey }}
  {{- $_ := unset $.Values.__EC_RESULT_DICT $resultKey }}

  {{- $_ := unset $map $key }}
  {{- if $newKey }}
    {{- $_ := set $map $newKey $value }}
  {{- end }}
{{- end }}

{{/*
  ======================================
  elcicd-renderer.replaceRefsInMapKey
  ======================================

  PARAMETERS LIST:
    $ -> root of chart
    $slice -> the slice (list) being processed for el-CICD variable references
    $elCicdDefs -> el-CICD variable definitions
    $processedVarsList -> list of variables tracked for debugging purposes
    $resultKey -> key used to store and retrieve results from the el-CICD Chart result dictionary

  ======================================

  Walk the given slice (list) and replace any el-CICD variable references with their values.  Each value will be processed, and
  if the value is an empty string, remove the value from the list.  Because lists are immutable in Helm, a new list is set in the
  el-CICD Chart result dictionary with the given key, and retrieved by the caller of this template.
*/}}
{{- define "elcicd-renderer.replaceVarRefsInSlice" }}
  {{- $ := get . "$" }}
  {{- $slice := .slice }}
  {{- $elCicdDefs := .elCicdDefs }}
  {{- $processedVarsList := .processedVarsList }}
  {{- $resultKey := .resultKey }}

  {{- $newSlice := list }}
  {{- $sliceResultKey := uuidv4 }}
  {{- range $element := $slice }}
    {{- include "elcicd-renderer.processValue"
                (dict "$" $ "value" $element "elCicdDefs" $elCicdDefs "processedVarsList" $processedVarsList "resultKey" $sliceResultKey) }}
    {{- $newElement := get $.Values.__EC_RESULT_DICT $sliceResultKey }}
    {{- $_ := unset $.Values.__EC_RESULT_DICT $sliceResultKey }}

    {{- if and (not (and (kindIs "string" $newElement) (empty $newElement))) (not (eq (typeOf $newElement) "<nil>")) }}
      {{- $newSlice = append $newSlice $newElement }}
    {{- end }}
  {{- end }}

  {{- $_ := set $.Values.__EC_RESULT_DICT $resultKey $newSlice }}
{{- end }}

{{/*
  ======================================
  elcicd-renderer.processValue
  ======================================

  PARAMETERS LIST:
    $ -> root of chart
    $value -> value to process for el-CICD variables
    $elCicdDefs -> el-CICD variable definitions
    $processedVarsList -> list of variables tracked for debugging purposes
    $resultKey -> key used to store and retrieve results from the el-CICD Chart result dictionary

  ======================================

  This is entry point for testing a value for possible el-CICD variable references.  The process is as follows:

  1. Add one to the recursive depth of this method
  2. Test whether the value is a
     - map (dictionary) - call "elcicd-renderer.replaceVarRefsInMap"
     - map (dictionary) - call "elcicd-renderer.replaceVarRefsInSlice"
     - map (dictionary) - call "elcicd-renderer.replaceVarRefsInString"
     - All other types are ignored and left as is
  2. Once processed, check if the processed value is different from the original value.
     i. If different, check that this template hasn't been called recursively more than __EC_MAX_DEPTH.
        a. If the depth exceeds the maximum, fail the el-CICD and log the debugging info of variables that
           caused the failure.
        b. Otherwise, recursive call the this template with the new value to check for other el-CICD variable
           references; i.e. realizing one el-CICD variable may inject new el-CICD variable references.
    ii. If they are the same, this means no el-CICD variable references were found.  Set the new value on el-CICD Chart
        result dictionary to be replaced by the calling template.
  3. Before completion, check if the depth is 1 (i.e. the beginning of processing the original value), and if so remove
     the backslash, '\', from any escaped el-CICD variable references (e.g. \$<ESCAPED_REF> -> $<ESCAPED_REF>).

*/}}
{{- define "elcicd-renderer.processValue" }}
  {{- $ := get . "$" }}
  {{- $value := .value }}
  {{- $elCicdDefs := .elCicdDefs }}
  {{- $processedVarsList := .processedVarsList }}
  {{- $resultKey := .resultKey }}

  {{- $depth := add1 (get $.Values.__EC_RESULT_DICT $.Values.__EC_DEPTH | default 0) }}
  {{- if eq $depth 1 }}
    {{- $_ := set $.Values.__EC_RESULT_DICT $.Values.__EC_ORIG_VALUE_KEY (substr 0 120 (toString $value)) }}
  {{- end }}

  {{- if (kindIs "map" $value) }}
    {{- include "elcicd-renderer.replaceVarRefsInMap"
                (dict "$" $ "map" $value "elCicdDefs" $elCicdDefs "processedVarsList" $processedVarsList) }}
    {{- $_ := set $.Values.__EC_RESULT_DICT $resultKey $value }}
  {{- else }}
    {{- if (kindIs "slice" $value) }}
      {{- include "elcicd-renderer.replaceVarRefsInSlice"
                  (dict "$" $ "slice" $value "elCicdDefs" $elCicdDefs "processedVarsList" $processedVarsList "resultKey" $resultKey) }}
    {{- else if (kindIs "string" $value) }}
      {{- $processedVarsKey := uuidv4 }}
      {{- include "elcicd-renderer.replaceVarRefsInString"
                  (dict "$" $ 
                        "value" $value
                        "elCicdDefs" $elCicdDefs
                        "processedVarsList" $processedVarsList
                        "resultKey" $resultKey
                        "processedVarsKey" $processedVarsKey) }}
      {{- $processedVarsList = get $.Values.__EC_RESULT_DICT $processedVarsKey }}
      {{- $_ := unset $.Values.__EC_RESULT_DICT $processedVarsKey }}
    {{- else }}
      {{- $_ := set $.Values.__EC_RESULT_DICT $resultKey $value }}
    {{- end  }}

    {{- $newValue := get $.Values.__EC_RESULT_DICT $resultKey }}
    {{- if and $newValue (ne (toYaml $value) (toYaml $newValue)) }}
      {{- $_ := set $.Values.__EC_RESULT_DICT $.Values.__EC_DEPTH $depth }}
      {{- if gt $depth $.Values.__EC_MAX_DEPTH }}
        {{- $origValue := get $.Values.__EC_RESULT_DICT $.Values.__EC_ORIG_VALUE_KEY }}
        {{- fail (print "Stack depth (" $.Values.__EC_MAX_DEPTH ") exceeded: \nVAR STACK: " (join " -> " $processedVarsList) "\nvalues.yaml REF: " $origValue) }}
      {{- end }}
      {{- include "elcicd-renderer.processValue"
                  (dict "$" $ "value" $newValue "elCicdDefs" $elCicdDefs "processedVarsList" $processedVarsList "resultKey" $resultKey) }}
    {{- end }}
    {{- $_ := set $.Values.__EC_RESULT_DICT $.Values.__EC_DEPTH (sub $depth 1) }}
  {{- end  }}

  {{- $value := get $.Values.__EC_RESULT_DICT $resultKey }}
  {{- if and (kindIs "string" $value) (eq $depth 1) }}
    {{- $_ := set $.Values.__EC_RESULT_DICT $resultKey (regexReplaceAll $.Values.__EC_ESCAPED_REGEX $value $.Values.__EC_UNESCAPED_REGEX) }}
  {{- end }}
{{- end }}

{{/*
  ======================================
  elcicd-renderer.replaceVarRefsInString
  ======================================

  PARAMETERS LIST:
    $ -> root of chart
    $value -> string to process for el-CICD variables
    $elCicdDefs -> el-CICD variable definitions
    $processedVarsList -> list of variables tracked for debugging purposes
    $resultKey -> key used to store and retrieve results from the el-CICD Chart result dictionary
    processedVarsKey -> key of where the processedVarsList is stored in the el-CICD Chart result dictionary

  ======================================

  Process a string for el-CICD variable references.  Eventually, maps (dictionaries) and slices (lists) will have values
  that resolve to strings.  These are where the references to el-CICD variables are replaced.

  el-CICD variables can resolve to other strings, in which case the containing value may have mutliple el-CICD references
  embedded in it.  el-CICD variables can also resolve to complex types such as maps and slices, in which case only a single
  match for an el-CICD reference is allowed.

  The result is returned in the el-CICD Chart result dictionary.  All variable references resolved are appended
  to the processed vars list.
*/}}
{{- define "elcicd-renderer.replaceVarRefsInString" }}
  {{- $ := get . "$" }}
  {{- $value := .value }}
  {{- $elCicdDefs := .elCicdDefs }}
  {{- $processedVarsList := .processedVarsList }}
  {{- $resultKey := .resultKey }}
  {{- $processedVarsKey := .processedVarsKey }}

  {{- $matches := regexFindAll $.Values.__EC_PARAM_REGEX $value -1 }}
  {{- $localProcessedVars := list }}
  {{- range $elCicdRef := $matches }}
    {{- $varConversion := regexReplaceAll $.Values.__EC_PARAM_REGEX $elCicdRef "${1}" }}
    {{- $elCicdVarName := regexReplaceAll $.Values.__EC_PARAM_REGEX $elCicdRef "${2}" }}
    {{- if not (has $elCicdRef $localProcessedVars) }}
      {{- $localProcessedVars = append $localProcessedVars $elCicdVarName }}
      {{- $varValue := get $elCicdDefs $elCicdVarName }}
      {{- if $varConversion }}
          {{- $varConversionKey := uuidv4 }}
          {{- include "elcicd-renderer.convertVar"
              (dict "$" $ "varConversion" $varConversion "varValue" $varValue "resultKey" $varConversionKey) }}
          {{- $varValue = get $.Values.__EC_RESULT_DICT $varConversionKey }}
          {{- $_ := unset $.Values.__EC_RESULT_DICT $varConversionKey }}
      {{- end }}

      {{- if (kindIs "string" $varValue) }}
        {{- if not (hasPrefix "$" $elCicdRef) }}
          {{- $elCicdRef = substr 1 (len $elCicdRef) $elCicdRef }}
        {{- end }}
        {{- if contains "\n" $varValue }}
          {{- $indentRegex := printf "%s%s" ".*" (replace "$" "[$]" $elCicdRef) }}
          {{- $indentation := regexFindAll $indentRegex $value 1 | first | replace $elCicdRef "" }}
          {{- if $indentation }}
            {{- $indentation = printf "%s%s" "\n" (repeat (len $indentation) " ") }}
            {{- $varValue = replace "\n" $indentation $varValue }}
          {{- end }}
        {{- end }}
        {{- $value = (replace $elCicdRef (toString $varValue) $value) }}
      {{- else }}
        {{- if (ne $elCicdRef $value) }}
          {{- fail (print "Attempting to insert non-string variables into string:\n" $elCicdVarName ": " (toYaml $varValue)) }}
        {{- end }}

        {{- if (kindIs "map" $varValue) }}
          {{- $varValue = deepCopy $varValue }}
        {{- else if (kindIs "slice" $varValue) }}
          {{- $newList := list }}
          {{- range $element := $varValue }}
            {{- if (kindIs "map" $element) }}
              {{- $element = deepCopy $element }}
            {{- end }}
            {{- $newList = append $newList $element }}
          {{- end }}
          {{- $varValue = $newList }}
        {{- end }}

        {{- $value = $varValue }}
      {{- end }}
    {{- end }}
  {{- end }}

  {{- $_ := set $.Values.__EC_RESULT_DICT $processedVarsKey (concat $processedVarsList ($localProcessedVars | uniq)) }}

  {{- $_ := set $.Values.__EC_RESULT_DICT $resultKey $value }}
{{- end }}

{{- define "elcicd-renderer.convertVar" }}
  {{- $ := get . "$" }}
  {{- $varConversion := .varConversion }}
  {{- $varValue := .varValue }}
  {{- $resultKey := .resultKey }}

  {{- if eq $varConversion "atoi" }}
    {{- $varValue = atoi $varValue }}
  {{- else if eq $varConversion "float64" }}
    {{- $varValue = float64 $varValue }}
  {{- else if eq $varConversion "int" }}
    {{- $varValue = int $varValue }}
  {{- else if eq $varConversion "int64" }}
    {{- $varValue = int64 $varValue }}
  {{- else if eq $varConversion "toDecimal" }}
    {{- $varValue = toDecimal $varValue }}
  {{- else if eq $varConversion "toString" }}
    {{- $varValue = toString $varValue }}
  {{- else if eq $varConversion "toStrings" }}
    {{- $varValue = toStrings $varValue }}
  {{- else if eq $varConversion "toJson" }}
    {{- $varValue = toJson $varValue }}
  {{- else if eq $varConversion "toPrettyJson" }}
    {{- $varValue = toPrettyJson $varValue }}
  {{- else if eq $varConversion "toRawJson" }}
    {{- $varValue = toRawJson $varValue }}
  {{- else if eq $varConversion "fromYaml" }}
    {{- $varValue = fromYaml $varValue }}
  {{- else if eq $varConversion "fromJson" }}
    {{- $varValue = fromJson $varValue }}
  {{- else if eq $varConversion "fromJsonArray" }}
    {{- $varValue = fromJsonArray $varValue }}
  {{- else if eq $varConversion "toYaml" }}
    {{- $varValue = toYaml $varValue }}
  {{- else if eq $varConversion "toToml" }}
    {{- $varValue = toToml $varValue }}
  {{- else if eq $varConversion "fromYamlArray" }}
    {{- $varValue = fromYamlArray $varValue }}
  {{- else }}
    {{- fail (printf "INVALID CONVERSION [%s] FOR VARIABLE [%s]" $varConversion $varValue) }}
  {{- end }}
  {{- $_ := set $.Values.__EC_RESULT_DICT $resultKey $varValue }}

{{- end }}

