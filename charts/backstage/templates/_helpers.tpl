{{- define "backstage.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "backstage.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "backstage.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: {{ include "backstage.name" . }}
{{- end }}

{{- define "backstage.selectorLabels" -}}
app.kubernetes.io/name: {{ include "backstage.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: backend
{{- end }}

{{- define "backstage.postgresql.fullname" -}}
{{- printf "%s-postgresql" (include "backstage.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "backstage.postgresql.selectorLabels" -}}
app.kubernetes.io/name: {{ include "backstage.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: postgresql
{{- end }}

{{- define "backstage.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "backstage.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
PostgreSQL password: explicit value, else the existing Secret's value, else a new random one.
*/}}
{{- define "backstage.postgresql.password" -}}
{{- if .Values.postgresql.password }}
{{- .Values.postgresql.password }}
{{- else }}
{{- $existing := lookup "v1" "Secret" .Release.Namespace (include "backstage.postgresql.fullname" .) }}
{{- if and $existing $existing.data (hasKey $existing.data "password") }}
{{- index $existing.data "password" | b64dec }}
{{- else }}
{{- randAlphaNum 32 }}
{{- end }}
{{- end }}
{{- end }}
