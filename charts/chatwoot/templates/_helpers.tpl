{{/*
全局环境配置与模式定义
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
*/}}
{{- define "chatwoot.storage.env" -}}
{{- if eq .Values.storage.type "s3" -}}
- name: ACTIVE_STORAGE_SERVICE
  value: "s3"
- name: S3_BUCKET_NAME
  value: {{ .Values.storage.s3.bucket | quote }}
- name: S3_REGION
  value: {{ .Values.storage.s3.region | quote }}
- name: S3_ACCESS_KEY_ID
  value: {{ .Values.storage.s3.accessKeyId | quote }}
- name: S3_SECRET_ACCESS_KEY
  value: {{ .Values.storage.s3.secretAccessKey | quote }}
{{- else if eq .Values.storage.type "gcs" -}}
- name: ACTIVE_STORAGE_SERVICE
  value: "google"
- name: GCS_BUCKET
  value: {{ .Values.storage.gcs.bucket | quote }}
- name: GCS_PROJECT
  value: {{ .Values.storage.gcs.project | quote }}
{{- else -}}
- name: ACTIVE_STORAGE_SERVICE
  value: "local"
{{- end -}}
{{- end -}}

{{/* 核心命名块 */}}
{{- define "chatwoot.name" -}}{{ default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}{{- end -}}
{{- define "chatwoot.full" -}}
{{- if .Values.fullnameOverride }}{{ .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}{{ printf "%s-%s" .Release.Name (include "chatwoot.name" .) | trunc 63 | trimSuffix "-" }}{{ end -}}
{{- end -}}

{{- define "chatwoot.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{- default (include "chatwoot.full" .) .Values.serviceAccount.name -}}
{{- else -}}
    {{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
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

{{/* 核心规范块 (Pod) */}}
{{- define "chatwoot.pod.common" -}}
{{- with .Values.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
affinity:
  nodeAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        preference:
          matchExpressions:
            - key: worker
              operator: In
              values:
                - "true"
  {{- if .Values.affinity }}
  {{- toYaml .Values.affinity | nindent 2 }}
  {{- else if .Values.global.affinity }}
  {{- toYaml .Values.global.affinity | nindent 2 }}
  {{- end }}
serviceAccountName: {{ include "chatwoot.serviceAccountName" . }}
volumes:
  - name: cache
    emptyDir:
      {{- if eq (default "" .Values.redis.master.persistence.medium) "Memory" }}
      medium: Memory
      {{- else }}
      {}
      {{- end }}
{{- end -}}

{{/* 环境变量块 */}}
{{- define "chatwoot.env.common" -}}
{{- include "chatwoot.storage.env" . }}
{{- if .Values.postgresql.auth.existingSecret }}
- name: POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.postgresql.auth.existingSecret | quote }}
      key: {{ default "password" .Values.postgresql.auth.secretKeys.adminPasswordKey | quote }}
{{- end }}
{{- if .Values.redis.auth.existingSecret }}
- name: REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.redis.auth.existingSecret | quote }}
      key: {{ default "password" .Values.redis.auth.existingSecretPasswordKey | quote }}
{{- end }}
{{- end -}}

{{- define "chatwoot.envFrom.common" -}}
- secretRef:
    name: {{ printf "%s-env" (include "chatwoot.full" .) | quote }}
{{- end -}}
