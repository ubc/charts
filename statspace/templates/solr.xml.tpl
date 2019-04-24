{{- /*
Configuration file for Solr used within DSpace
*/ -}}
{{- define "solr.xml" -}}
<?xml version="1.0" encoding="UTF-8" ?>
<!--
 Licensed to the Apache Software Foundation (ASF) under one or more
 contributor license agreements.  See the NOTICE file distributed with
 this work for additional information regarding copyright ownership.
 The ASF licenses this file to You under the Apache License, Version 2.0
 (the "License"); you may not use this file except in compliance with
 the License.  You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
-->

<!--
 All (relative) paths are relative to the installation path
  
  persistent: Save changes made via the API to this file
  sharedLib: path to a lib directory that will be shared across all cores
-->
<solr persistent="false">

  <!--
  adminPath: RequestHandler path to manage cores.  
    If 'null' (or absent), cores will not be manageable via REST
  -->
  <cores adminPath="/admin/cores">
    <core name="search" instanceDir="search" />
    {{- if .Values.persistence.enabled }}
    <core name="statistics" instanceDir="statistics" dataDir="/dspace/persistent/solr/statistics/data" />
    {{- else }}
    <core name="statistics" instanceDir="statistics" />
    {{- end }}
    <core name="oai" instanceDir="oai" />
    <core name="authority" instanceDir="authority" />
  </cores>
  
</solr>
{{- end -}}