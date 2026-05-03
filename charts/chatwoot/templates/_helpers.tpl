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

{{/* --- [ 极客迁移引擎: 动态桥接逻辑 ] --- */}}
{{/* 获取旧实例的基础名称 (优先取配置，没填取 Release.Name) */}}
{{- define "chatwoot.migration.legacyName" -}}
{{- default .Release.Name .Values.migration.legacyInstanceName -}}
{{- end -}}



{{/* 动态生成旧版 Secret 名称 */}}
{{- define "chatwoot.migration.secret" -}}
{{- if .Values.migration.enabled -}}
{{- printf "%s-chatwoot-postgresql" (include "chatwoot.migration.legacyName" .) -}}
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
{{/* 返回完整前缀 (e.g., chatwoot-2-1766892187) - 针对子 Chart (Redis/PG) 挂载 */}}
{{- define "chatwoot.full" -}}
{{- if .Values.fullnameOverride }}{{ .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else if contains .Chart.Name .Release.Name }}{{ .Release.Name }}
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

{{/* 基础设施连接检测: 极客版原子化命名 (ReleaseName 改名为 chatwoot) */}}
{{- define "chatwoot.db.host" -}}
{{- if .Values.postgresql.postgresqlHost }}{{ .Values.postgresql.postgresqlHost }}
{{- else if .Values.postgresql.enabled }}{{ printf "chatwoot-postgresql" }}
{{- else }}localhost{{ end -}}
{{- end -}}

{{- define "chatwoot.db.port" -}}{{ default "5432" .Values.postgresql.postgresqlPort }}{{ end -}}

{{- define "chatwoot.cache.host" -}}
{{- if .Values.redis.host }}{{ .Values.redis.host }}
{{- else if .Values.redis.enabled }}{{ printf "chatwoot-redis-master" }}
{{- else }}localhost{{ end -}}
{{- end -}}
{{- define "chatwoot.cache.port" -}}{{ default "6379" .Values.redis.port }}{{ end -}}

{{/* 核心规范块 (Pod) */}}
{{- define "chatwoot.pod.common" -}}
{{- with .Values.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
affinity:
  {{- if .Values.affinity }}
  {{- toYaml .Values.affinity | nindent 2 }}
  {{- else if .Values.global.affinity }}
  {{- toYaml .Values.global.affinity | nindent 2 }}
  {{- else }}
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: worker
              operator: Exists
            - key: longhorn
              operator: Exists
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
  {{- if .Values.persistence.enabled }}
  - name: storage
    persistentVolumeClaim:
      claimName: chatwoot-storage
  {{- end }}
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
terminationGracePeriodSeconds: 60
{{- end -}}

{{/* Secret data block. Checksums must use this instead of the whole base.yaml so metadata-only changes do not restart pods. */}}
{{- define "chatwoot.env.secretData" -}}
POSTGRES_HOST: {{ include "chatwoot.db.host" . | b64enc | quote }}
POSTGRES_PORT: {{ default "5432" .Values.postgresql.postgresqlPort | toString | b64enc | quote }}
POSTGRES_USERNAME: {{ default "postgres" .Values.postgresql.auth.username | b64enc | quote }}
POSTGRES_DATABASE: {{ default "chatwoot_production" .Values.postgresql.auth.database | b64enc | quote }}
{{- if and (not .Values.postgresql.enabled) (not .Values.postgresql.auth.existingSecret) }}
{{- /* 外部 PG：密码通过 values.override.yaml 的 env.POSTGRES_PASSWORD 传入 */}}
{{- else if not .Values.postgresql.auth.existingSecret }}
POSTGRES_PASSWORD: {{ default "postgres" .Values.postgresql.auth.postgresPassword | b64enc | quote }}
{{- end }}
REDIS_URL: {{ (printf "redis://%s:%s" (include "chatwoot.cache.host" .) (default "6379" .Values.redis.port | toString)) | b64enc | quote }}
{{- range $k, $v := .Values.env }}
{{ $k }}: {{ $v | toString | b64enc | quote }}
{{- end }}
{{- end -}}

{{/* 环境变量块 */}}
{{- define "chatwoot.env.common" -}}
{{- include "chatwoot.storage.env" . }}
{{- if .Values.postgresql.enabled -}}
{{- $secretName := .Values.postgresql.auth.existingSecret -}}
{{- if and (not $secretName) .Values.migration.enabled -}}
  {{- $secretName = include "chatwoot.migration.secret" . -}}
{{- end -}}
{{- if $secretName }}
- name: POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ $secretName | quote }}
      key: {{ default "password" .Values.postgresql.auth.secretKeys.adminPasswordKey | quote }}
{{- end }}
{{- end }}
{{- if and .Values.redis.enabled .Values.redis.auth.existingSecret }}
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
{{- if .Values.existingEnvSecret }}
- secretRef:
    name: {{ .Values.existingEnvSecret }}
{{- end }}
{{- end -}}
