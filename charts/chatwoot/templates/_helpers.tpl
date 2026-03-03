{{/*
全局环境 Profile
*/}}
{{- define "chatwoot.profile" -}}
{{- default "production" .Values.global.mode -}}
{{- end -}}

{{/*
智能副本分配器
*/}}
{{- define "chatwoot.app.replicas" -}}
{{- $cfg := index .context.Values .component -}}
{{- if $cfg.replicaCount }}{{ $cfg.replicaCount }}
{{- else if eq (include "chatwoot.profile" .context) "production" }}2
{{- else }}1
{{- end -}}
{{- end -}}

{{/* 
存储配置生成器 (Geek Edition)
根据 .Values.storage.type 自动生成 Chatwoot 所需的所有环境变量
*/}}
{{- define "chatwoot.storage.env" -}}
{{- if eq .Values.storage.type "s3" -}}
- {name: ACTIVE_STORAGE_SERVICE, value: "s3"}
- {name: S3_BUCKET_NAME, value: {{ .Values.storage.s3.bucket | quote }}}
- {name: S3_REGION, value: {{ .Values.storage.s3.region | quote }}}
- {name: S3_ACCESS_KEY_ID, value: {{ .Values.storage.s3.accessKeyId | quote }}}
- {name: S3_SECRET_ACCESS_KEY, value: {{ .Values.storage.s3.secretAccessKey | quote }}}
{{- else if eq .Values.storage.type "gcs" -}}
- {name: ACTIVE_STORAGE_SERVICE, value: "google"}
- {name: GCS_BUCKET, value: {{ .Values.storage.gcs.bucket | quote }}}
- {name: GCS_PROJECT, value: {{ .Values.storage.gcs.project | quote }}}
{{- else -}}
- {name: ACTIVE_STORAGE_SERVICE, value: "local"}
{{- end -}}
{{- end -}}

{{/* 核心命名逻辑 */}}
{{- define "chatwoot.name" -}}{{ default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}{{- end -}}
{{- define "chatwoot.full" -}}
{{- if .Values.fullnameOverride }}{{ .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}{{ printf "%s-%s" .Release.Name (include "chatwoot.name" .) | trunc 63 | trimSuffix "-" }}{{ end -}}
{{- end -}}

{{/* 元数据标签生成 */}}
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

{{/* 基础设施连接检测 */}}
{{- define "chatwoot.db.host" -}}{{ if .Values.postgresql.enabled }}{{ printf "%s-postgresql" .Release.Name }}{{ else }}{{ .Values.postgresql.postgresqlHost }}{{ end }}{{ end -}}
{{- define "chatwoot.db.port" -}}{{ default "5432" .Values.postgresql.postgresqlPort }}{{ end -}}
{{- define "chatwoot.cache.host" -}}{{ if .Values.redis.enabled }}{{ printf "%s-redis-master" .Release.Name }}{{ else }}{{ .Values.redis.host }}{{ end }}{{ end -}}
{{- define "chatwoot.cache.port" -}}{{ default "6379" .Values.redis.port }}{{ end -}}

{{/* 核心定义块 (Pod & Env) */}}
{{- define "chatwoot.pod.common" -}}
{{- with .Values.imagePullSecrets }}imagePullSecrets: {{ toYaml . | nindent 2 }}{{ end }}
{{- with (default .Values.affinity .Values.global.affinity) }}affinity: {{ toYaml . | nindent 2 }}{{ end }}
volumes: [{name: cache, emptyDir: {}}]
{{- end -}}

{{- define "chatwoot.env.common" -}}
{{- include "chatwoot.storage.env" . }}
{{- if .Values.postgresql.auth.existingSecret -}}
- {name: POSTGRES_PASSWORD, valueFrom: {secretKeyRef: {name: {{ .Values.postgresql.auth.existingSecret }}, key: {{ default "password" .Values.postgresql.auth.secretKeys.adminPasswordKey | quote }}}}}
{{- end }}
{{- if .Values.redis.auth.existingSecret -}}
- {name: REDIS_PASSWORD, valueFrom: {secretKeyRef: {name: {{ .Values.redis.auth.existingSecret }}, key: {{ default "password" .Values.redis.auth.existingSecretPasswordKey | quote }}}}}
{{- end }}
envFrom: [{secretRef: {name: "{{ include "chatwoot.full" . }}-env"}}]
{{- end -}}
