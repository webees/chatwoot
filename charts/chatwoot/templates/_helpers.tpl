{{/*
Global Context & Mode
Valid modes: production, lite
*/}}
{{- define "chatwoot.mode" -}}
{{- default "production" .Values.global.mode -}}
{{- end -}}

{{/*
Dynamic Replicas based on Profile
*/}}
{{- define "chatwoot.web.replicas" -}}
{{- if .Values.web.replicaCount -}}
{{- .Values.web.replicaCount -}}
{{- else if eq (include "chatwoot.mode" .) "production" -}}
2
{{- else -}}
1
{{- end -}}
{{- end -}}

{{- define "chatwoot.worker.replicas" -}}
{{- if .Values.worker.replicaCount -}}
{{- .Values.worker.replicaCount -}}
{{- else if eq (include "chatwoot.mode" .) "production" -}}
2
{{- else -}}
1
{{- end -}}
{{- end -}}

{{/*
Expand the name of the chart.
*/}}
{{- define "chatwoot.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "chatwoot.full" -}}
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
Common labels
*/}}
{{- define "chatwoot.labels" -}}
helm.sh/chart: {{ include "chatwoot.chart" . }}
{{ include "chatwoot.selector" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "chatwoot.selector" -}}
app.kubernetes.io/name: {{ include "chatwoot.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Chart name and version
*/}}
{{- define "chatwoot.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Service Account Name
*/}}
{{- define "chatwoot.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "chatwoot.full" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Database (PostgreSQL) Helpers
*/}}
{{- define "chatwoot.db.full" -}}
{{- if .Values.postgresql.fullnameOverride -}}
{{- .Values.postgresql.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name "chatwoot-postgresql" | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "chatwoot.db.host" -}}
{{- if .Values.postgresql.enabled -}}
{{- include "chatwoot.db.full" . -}}
{{- else -}}
{{- .Values.postgresql.postgresqlHost -}}
{{- end -}}
{{- end -}}

{{- define "chatwoot.db.port" -}}
{{- default 5432 .Values.postgresql.postgresqlPort -}}
{{- end -}}

{{/*
Cache (Redis) Helpers
*/}}
{{- define "chatwoot.cache.full" -}}
{{- if .Values.redis.fullnameOverride -}}
{{- .Values.redis.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name "chatwoot-redis" | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "chatwoot.cache.host" -}}
{{- if .Values.redis.enabled -}}
{{- include "chatwoot.cache.full" . -}}-master
{{- else -}}
{{- .Values.redis.host }}
{{- end -}}
{{- end -}}

{{- define "chatwoot.cache.port" -}}
{{- default 6379 .Values.redis.port -}}
{{- end -}}

{{- define "chatwoot.cache.password" -}}
{{- if .Values.redis.enabled -}}
{{- default "redis" .Values.redis.auth.password -}}
{{- else -}}
{{- default "redis" .Values.redis.password -}}
{{- end -}}
{{- end -}}

{{- define "chatwoot.cache.url" -}}
{{- if .Values.redis.enabled -}}
    redis://:{{ include "chatwoot.cache.password" . }}@{{ include "chatwoot.cache.host" . }}:{{ include "chatwoot.cache.port" . }}
{{- else -}}
    redis://:$(REDIS_PASSWORD)@{{ .Values.redis.host }}:{{ .Values.redis.port }}
{{- end -}}
{{- end -}}

{{/*
Composition Modules
*/}}
{{- define "chatwoot.pod.common" -}}
{{- with .Values.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- if .Values.nodeSelector }}
nodeSelector: {{- include "common.tplvalues.render" (dict "value" .Values.nodeSelector "context" $) | nindent 2 }}
{{- end }}
{{- if .Values.affinity }}
affinity:
  {{- toYaml .Values.affinity | nindent 2 }}
{{- end }}
{{- if .Values.topologySpreadConstraints }}
topologySpreadConstraints:
  {{- toYaml .Values.topologySpreadConstraints | nindent 2 }}
{{- end }}
volumes:
  - name: cache
    emptyDir: {}
{{- end -}}

{{- define "chatwoot.env.common" -}}
{{- if .Values.postgresql.auth.existingSecret }}
- name: POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.postgresql.auth.existingSecret }}
      key: {{ default "password" .Values.postgresql.auth.secretKeys.adminPasswordKey | quote }}
{{- end }}
{{- if .Values.redis.auth.existingSecret }}
- name: REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.redis.auth.existingSecret }}
      key: {{ default "password" .Values.redis.auth.existingSecretPasswordKey | quote }}
{{- end }}
envFrom:
  - secretRef:
      name: {{ include "chatwoot.full" . }}-env
  {{- if .Values.existingEnvSecret }}
  - secretRef:
      name: {{ .Values.existingEnvSecret }}
  {{- end }}
{{- end -}}
