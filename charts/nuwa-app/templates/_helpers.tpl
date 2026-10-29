{{/* Selector labels - fixed for the app's lifetime. */}}
{{- define "nuwa-app.selectorLabels" -}}
app.kubernetes.io/name: {{ .Values.name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/* Every resource carries these: the selector pair plus Meru's CMDB labels (compliance rule 7). */}}
{{- define "nuwa-app.labels" -}}
{{ include "nuwa-app.selectorLabels" . }}
app.kubernetes.io/part-of: {{ .Values.partOf }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
meru.clockmost.com/owner: {{ .Values.owner }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}

{{/* repository[:tag]@digest - the digest decides what runs (rule 1), the tag is for people. */}}
{{- define "nuwa-app.image" -}}
{{ .Values.image.repository }}{{ with .Values.image.tag }}:{{ . }}{{ end }}@{{ .Values.image.digest }}
{{- end }}

{{/* env entries from Secrets: {NAME: {secret, key}} -> valueFrom.secretKeyRef. */}}
{{- define "nuwa-app.secretEnv" -}}
{{- range $name, $ref := . }}
- name: {{ $name }}
  valueFrom:
    secretKeyRef:
      name: {{ $ref.secret }}
      key: {{ $ref.key }}
{{- end }}
{{- end }}

{{/* The migration Job's labels: the CMDB labels, but its own name, so no app selector ever matches it. */}}
{{- define "nuwa-app.migrateLabels" -}}
app.kubernetes.io/name: {{ .Values.name }}-migrate
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: migrate
app.kubernetes.io/part-of: {{ .Values.partOf }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
meru.clockmost.com/owner: {{ .Values.owner }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}
