{{/*
🏷️ 扩展 Chart 名称
*/}}
{{- define "chatwoot.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
🔖 创建完整应用名称
*/}}
{{- define "chatwoot.fullname" -}}
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

{{/*
📊 Chart 名称和版本
*/}}
{{- define "chatwoot.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
🏷️ 通用标签
*/}}
{{- define "chatwoot.labels" -}}
helm.sh/chart: {{ include "chatwoot.chart" . }}
{{ include "chatwoot.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
🎯 选择器标签
*/}}
{{- define "chatwoot.selectorLabels" -}}
app.kubernetes.io/name: {{ include "chatwoot.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
👤 ServiceAccount 名称
*/}}
{{- define "chatwoot.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "chatwoot.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
🐘 PostgreSQL 完整名称
*/}}
{{- define "chatwoot.postgresql.fullname" -}}
{{- if .Values.postgresql.fullnameOverride -}}
{{- .Values.postgresql.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.postgresql.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name "chatwoot-postgresql" | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
🔴 Redis 完整名称
*/}}
{{- define "chatwoot.redis.fullname" -}}
{{- if .Values.redis.fullnameOverride -}}
{{- .Values.redis.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.redis.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name "chatwoot-redis" | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
🐘 PostgreSQL 主机
*/}}
{{- define "chatwoot.postgresql.host" -}}
{{- if .Values.postgresql.enabled -}}
{{- template "chatwoot.postgresql.fullname" . -}}
{{- else -}}
{{- .Values.postgresql.postgresqlHost -}}
{{- end -}}
{{- end -}}

{{/*
🔐 PostgreSQL Secret
*/}}
{{- define "chatwoot.postgresql.secret" -}}
{{- if .Values.postgresql.enabled -}}
{{- template "chatwoot.postgresql.fullname" . -}}
{{- else -}}
{{- template "chatwoot.fullname" . -}}
{{- end -}}
{{- end -}}

{{/*
🔑 PostgreSQL Secret Key
*/}}
{{- define "chatwoot.postgresql.secretKey" -}}
{{- if .Values.postgresql.enabled -}}
"postgresql-password"
{{- else -}}
{{- default "postgresql-password" .Values.postgresql.auth.secretKeys.adminPasswordKey | quote -}}
{{- end -}}
{{- end -}}

{{/*
🔌 PostgreSQL 端口
*/}}
{{- define "chatwoot.postgresql.port" -}}
{{- if .Values.postgresql.enabled -}}
5432
{{- else -}}
{{- default 5432 .Values.postgresql.postgresqlPort -}}
{{- end -}}
{{- end -}}

{{/*
🔴 Redis 主机
*/}}
{{- define "chatwoot.redis.host" -}}
{{- if .Values.redis.enabled -}}
{{- template "chatwoot.redis.fullname" . -}}-master
{{- else -}}
{{- .Values.redis.host }}
{{- end -}}
{{- end -}}

{{/*
🔐 Redis Secret
*/}}
{{- define "chatwoot.redis.secret" -}}
{{- if .Values.redis.enabled -}}
{{- template "chatwoot.redis.fullname" . -}}
{{- else -}}
{{- template "chatwoot.fullname" . -}}
{{- end -}}
{{- end -}}

{{/*
🔑 Redis Secret Key
*/}}
{{- define "chatwoot.redis.secretKey" -}}
{{- if .Values.redis.enabled -}}
"redis-password"
{{- else -}}
{{- default "redis-password" .Values.redis.existingSecretPasswordKey | quote -}}
{{- end -}}
{{- end -}}

{{/*
🔌 Redis 端口
*/}}
{{- define "chatwoot.redis.port" -}}
{{- if .Values.redis.enabled -}}
6379
{{- else -}}
{{- default 6379 .Values.redis.port -}}
{{- end -}}
{{- end -}}

{{/*
🔑 Redis 密码
*/}}
{{- define "chatwoot.redis.password" -}}
{{- if .Values.redis.enabled -}}
{{- default "redis" .Values.redis.auth.password -}}
{{- else -}}
{{- default "redis" .Values.redis.password -}}
{{- end -}}
{{- end -}}

{{/*
🔗 Redis URL
*/}}
{{- define "chatwoot.redis.url" -}}
{{- if .Values.redis.enabled -}}
redis://:{{ .Values.redis.auth.password }}@{{ template "chatwoot.redis.host" . }}:{{ template "chatwoot.redis.port" . }}
{{- else if .Values.env.REDIS_TLS -}}
rediss://:$(REDIS_PASSWORD)@{{ .Values.redis.host }}:{{ .Values.redis.port }}
{{- else -}}
redis://:$(REDIS_PASSWORD)@{{ .Values.redis.host }}:{{ .Values.redis.port }}
{{- end -}}
{{- end -}}

{{/*
🔧 渲染模板值
*/}}
{{- define "common.tplvalues.render" -}}
{{- if typeIs "string" .value }}
{{- tpl .value .context }}
{{- else }}
{{- tpl (.value | toYaml) .context }}
{{- end }}
{{- end -}}
