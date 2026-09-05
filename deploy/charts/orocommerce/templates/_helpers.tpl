{{- define "orocommerce.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "orocommerce.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "orocommerce.labels" -}}
app.kubernetes.io/name: {{ include "orocommerce.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end -}}

{{- define "orocommerce.selectorLabels" -}}
app.kubernetes.io/name: {{ include "orocommerce.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "orocommerce.componentLabels" -}}
{{ include "orocommerce.labels" . }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "orocommerce.componentSelectorLabels" -}}
{{ include "orocommerce.selectorLabels" . }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{/*
Shared non-secret + secret-ref env for Oro app workloads (fpm/consumer/cron/websocket/bootstrap).
*/}}
{{- define "orocommerce.appEnv" -}}
- name: APP_DIR
  value: /var/www
- name: PHP_UID
  value: "1000"
- name: PHP_GID
  value: "1000"
- name: XDEBUG_MODE
  value: "off"
- name: ORO_OAUTH_PRIVATE_KEY_PATH
  value: "%kernel.project_dir%/var/data/oauth/oauth_private.key"
- name: ORO_OAUTH_PUBLIC_KEY_PATH
  value: "%kernel.project_dir%/var/data/oauth/oauth_public.key"
- name: ORO_INSTALL_MODE
  value: {{ .Values.bootstrap.installMode | quote }}
- name: ORO_DUMP_NAME
  value: {{ .Values.config.ORO_DUMP_NAME | quote }}
- name: ORO_WEBSOCKET_BACKEND_DSN
  value: {{ printf "tcp://%s-websocket:8080" (include "orocommerce.fullname" .) | quote }}
- name: ORO_WEBSOCKET_FRONTEND_DSN
  value: "//*:443/ws"
{{- if .Values.gotenberg.enabled }}
- name: ORO_PDF_GENERATOR_GOTENBERG_API_URL
  value: {{ printf "http://%s-gotenberg:3000" (include "orocommerce.fullname" .) | quote }}
{{- end }}
{{- /* Staging mail always points at in-cluster Mailpit (design.md decision 6). */}}
{{- if .Values.mailpit.enabled }}
- name: ORO_MAILER_DSN
  value: {{ printf "smtp://%s-mailpit:1025" (include "orocommerce.fullname" .) | quote }}
{{- end }}
- name: ORO_ENV
  valueFrom:
    configMapKeyRef:
      name: {{ include "orocommerce.fullname" . }}-config
      key: ORO_ENV
- name: ORO_SKIP_COMPOSER
  valueFrom:
    configMapKeyRef:
      name: {{ include "orocommerce.fullname" . }}-config
      key: ORO_SKIP_COMPOSER
- name: ORO_APP_URL
  valueFrom:
    configMapKeyRef:
      name: {{ include "orocommerce.fullname" . }}-config
      key: ORO_APP_URL
- name: ORO_PUBLIC_HOST
  valueFrom:
    configMapKeyRef:
      name: {{ include "orocommerce.fullname" . }}-config
      key: ORO_PUBLIC_HOST
- name: ORO_PUBLIC_HTTPS
  valueFrom:
    configMapKeyRef:
      name: {{ include "orocommerce.fullname" . }}-config
      key: ORO_PUBLIC_HTTPS
- name: ORO_MAILER_ENCRYPTION
  valueFrom:
    configMapKeyRef:
      name: {{ include "orocommerce.fullname" . }}-config
      key: ORO_MAILER_ENCRYPTION
- name: ORO_MQ_DSN
  valueFrom:
    configMapKeyRef:
      name: {{ include "orocommerce.fullname" . }}-config
      key: ORO_MQ_DSN
- name: ORO_SESSION_DSN
  valueFrom:
    configMapKeyRef:
      name: {{ include "orocommerce.fullname" . }}-config
      key: ORO_SESSION_DSN
- name: ORO_SEARCH_URL
  valueFrom:
    configMapKeyRef:
      name: {{ include "orocommerce.fullname" . }}-config
      key: ORO_SEARCH_URL
- name: ORO_SEARCH_ENGINE_DSN
  valueFrom:
    configMapKeyRef:
      name: {{ include "orocommerce.fullname" . }}-config
      key: ORO_SEARCH_ENGINE_DSN
- name: ORO_WEBSITE_SEARCH_ENGINE_DSN
  valueFrom:
    configMapKeyRef:
      name: {{ include "orocommerce.fullname" . }}-config
      key: ORO_WEBSITE_SEARCH_ENGINE_DSN
- name: ORO_WEBSOCKET_SERVER_DSN
  valueFrom:
    configMapKeyRef:
      name: {{ include "orocommerce.fullname" . }}-config
      key: ORO_WEBSOCKET_SERVER_DSN
- name: ORO_LOG_PATH
  valueFrom:
    configMapKeyRef:
      name: {{ include "orocommerce.fullname" . }}-config
      key: ORO_LOG_PATH
- name: ORO_SAMPLE_DATA
  valueFrom:
    configMapKeyRef:
      name: {{ include "orocommerce.fullname" . }}-config
      key: ORO_SAMPLE_DATA
- name: ORO_LANGUAGE
  valueFrom:
    configMapKeyRef:
      name: {{ include "orocommerce.fullname" . }}-config
      key: ORO_LANGUAGE
- name: ORO_FORMATTING_CODE
  valueFrom:
    configMapKeyRef:
      name: {{ include "orocommerce.fullname" . }}-config
      key: ORO_FORMATTING_CODE
- name: ORO_USER_NAME
  valueFrom:
    configMapKeyRef:
      name: {{ include "orocommerce.fullname" . }}-config
      key: ORO_USER_NAME
- name: ORO_USER_EMAIL
  valueFrom:
    configMapKeyRef:
      name: {{ include "orocommerce.fullname" . }}-config
      key: ORO_USER_EMAIL
- name: ORO_ORGANIZATION_NAME
  valueFrom:
    configMapKeyRef:
      name: {{ include "orocommerce.fullname" . }}-config
      key: ORO_ORGANIZATION_NAME
- name: ORO_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secret.name }}
      key: ORO_SECRET
- name: ORO_DB_URL
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secret.name }}
      key: ORO_DB_URL
- name: ORO_DB_DSN
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secret.name }}
      key: ORO_DB_DSN
- name: ORO_DUMP_URL
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secret.name }}
      key: ORO_DUMP_URL
      optional: true
{{- if .Values.admin.rotatePassword }}
- name: ORO_USER_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secret.name }}
      key: ORO_USER_PASSWORD
{{- end }}
{{- end -}}

{{- define "orocommerce.appVolumeMounts" -}}
- name: var-data
  mountPath: /var/www/var/data
- name: media
  mountPath: /var/www/public/media
- name: dumps
  mountPath: /dumps
- name: cache
  mountPath: /var/www/var/cache
- name: sessions
  mountPath: /var/www/var/sessions
{{- end -}}

{{- define "orocommerce.appVolumes" -}}
- name: var-data
  persistentVolumeClaim:
    claimName: {{ include "orocommerce.fullname" . }}-var-data
- name: media
  persistentVolumeClaim:
    claimName: {{ include "orocommerce.fullname" . }}-media
- name: dumps
  emptyDir: {}
- name: cache
  emptyDir: {}
- name: sessions
  emptyDir: {}
{{- end -}}

{{/*
Init container: wait until bootstrap Job has finished (oro_is_installed).
Needed because the Job is post-install (must run after Postgres exists) and
therefore races with Deployments on first install.
*/}}
{{- define "orocommerce.waitBootstrapInit" -}}
- name: wait-bootstrap
  image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
  imagePullPolicy: {{ .Values.image.pullPolicy }}
  command:
    - sh
    - -c
    - |
      set -euo pipefail
      . /usr/local/bin/oro-lib
      echo "[wait-bootstrap] waiting for oro_is_installed..."
      for i in $(seq 1 360); do
        if oro_is_installed; then
          echo "[wait-bootstrap] application is installed"
          exit 0
        fi
        sleep 10
      done
      echo "[wait-bootstrap] timed out waiting for bootstrap Job" >&2
      exit 1
  env:
    {{- include "orocommerce.appEnv" . | nindent 4 }}
  volumeMounts:
    {{- include "orocommerce.appVolumeMounts" . | nindent 4 }}
{{- end -}}
