{{/*
全局环境配置与模式定义
- production: 高可用模式，默认 2+ 副本，开启强安全隔离
- lite: 轻量模式，单 Pod 运行，节省资源，适合开发测试
*/}}
{{- define "chatwoot.profile" -}}
{{- default "production" .Values.global.mode -}}
{{- end -}}

{{/*
动态副本计算逻辑
参数格式: (dict "context" . "component" "web")
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

{{/* 核心命名块 */}}
{{- define "chatwoot.name" -}}{{ default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}{{- end -}}
{{- define "chatwoot.full" -}}
{{- if .Values.fullnameOverride }}{{ .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}{{ printf "%s-%s" .Release.Name (include "chatwoot.name" .) | trunc 63 | trimSuffix "-" }}{{ end -}}
{{- end -}}

{{/* 元数据标签生成器 */}}
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

{{/* 存储与网络组件地址助手 */}}
{{- define "chatwoot.db.host" -}}{{ if .Values.postgresql.enabled }}{{ printf "%s-postgresql" .Release.Name }}{{ else }}{{ .Values.postgresql.postgresqlHost }}{{ end }}{{ end -}}
{{- define "chatwoot.cache.host" -}}{{ if .Values.redis.enabled }}{{ printf "%s-redis-master" .Release.Name }}{{ else }}{{ .Values.redis.host }}{{ end }}{{ end -}}

{{/* 核心规范块 (极简定义) */}}
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
