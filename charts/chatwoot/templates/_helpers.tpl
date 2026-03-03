{{/*
Global Context & Profile
- production: HA, 2+ replicas, high security
- lite: Single pod, low resources
*/}}
{{- define "chatwoot.profile" -}}
{{- default "production" .Values.global.mode -}}
{{- end -}}

{{/*
Dynamic App Replicas Logic
Args: (dict "context" . "component" "web")
*/}}
{{- define "chatwoot.app.replicas" -}}
{{- $config := index .context.Values .component -}}
{{- if $config.replicaCount -}}
{{- $config.replicaCount -}}
{{- else if eq (include "chatwoot.profile" .context) "production" -}}
{{- if eq .component "worker" }}2{{ else }}2{{ end -}}
{{- else -}}
1
{{- end -}}
{{- end -}}

{{/* Simple Naming Blocks */}}
{{- define "chatwoot.name" -}}{{ default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}{{- end -}}
{{- define "chatwoot.full" -}}
{{- if .Values.fullnameOverride }}{{ .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}{{ printf "%s-%s" .Release.Name (include "chatwoot.name" .) | trunc 63 | trimSuffix "-" }}{{ end -}}
{{- end -}}

{{/* Metadata Generators */}}
{{- define "chatwoot.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{ include "chatwoot.selector" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "chatwoot.selector" -}}
app.kubernetes.io/name: {{ include "chatwoot.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/* Storage & Network Helpers */}}
{{- define "chatwoot.db.host" -}}{{ if .Values.postgresql.enabled }}{{ printf "%s-postgresql" .Release.Name }}{{ else }}{{ .Values.postgresql.postgresqlHost }}{{ end }}{{ end -}}
{{- define "chatwoot.cache.host" -}}{{ if .Values.redis.enabled }}{{ printf "%s-redis-master" .Release.Name }}{{ else }}{{ .Values.redis.host }}{{ end }}{{ end -}}

{{/* Core Spec Blocks (Minimalist) */}}
{{- define "chatwoot.pod.common" -}}
{{- with .Values.imagePullSecrets }}imagePullSecrets: {{ toYaml . | nindent 2 }}{{ end }}
{{- with (default .Values.affinity .Values.global.affinity) }}affinity: {{ toYaml . | nindent 2 }}{{ end }}
volumes: [{name: cache, emptyDir: {}}]
{{- end -}}

{{- define "chatwoot.env.common" -}}
{{- if .Values.postgresql.auth.existingSecret -}}
- {name: POSTGRES_PASSWORD, valueFrom: {secretKeyRef: {name: {{ .Values.postgresql.auth.existingSecret }}, key: {{ default "password" .Values.postgresql.auth.secretKeys.adminPasswordKey | quote }}}}}
{{- end }}
{{- if .Values.redis.auth.existingSecret -}}
- {name: REDIS_PASSWORD, valueFrom: {secretKeyRef: {name: {{ .Values.redis.auth.existingSecret }}, key: {{ default "password" .Values.redis.auth.existingSecretPasswordKey | quote }}}}}
{{- end }}
envFrom: [{secretRef: {name: "{{ include "chatwoot.full" . }}-env"}}]
{{- end -}}
