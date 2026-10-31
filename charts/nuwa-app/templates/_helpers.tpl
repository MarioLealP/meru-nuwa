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

{{/* A pod's labels: the selector pair plus the CMDB labels rule 7 asks of pods - no chart version, so a chart bump
alone never changes the pod template (and never restarts every app). */}}
{{- define "nuwa-app.podLabels" -}}
{{ include "nuwa-app.selectorLabels" . }}
app.kubernetes.io/part-of: {{ .Values.partOf }}
meru.clockmost.com/owner: {{ .Values.owner }}
{{- end }}

{{/* repository[:tag]@digest - the digest decides what runs (rule 1), the tag is for people. */}}
{{- define "nuwa-app.image" -}}
{{ .Values.image.repository }}{{ with .Values.image.tag }}:{{ . }}{{ end }}@{{ .Values.image.digest }}
{{- end }}

{{/* Whether the workload (Deployment, migration Job, ScaledObject) renders. Not until CI's first build - the digest is
the template's all-zero placeholder, Kyverno would refuse it (no signature) and Argo CD would keep retrying that revision
instead of taking the build's digest commit - and not once the app is retired (`enabled: false`, D84: Shikigami's last
commit before it archives the repo; the pods stop on the next sync). Everything else (Service, volumes, secrets, ...)
renders either way, until Charon purges the namespace. */}}
{{- define "nuwa-app.runs" -}}
{{- if and .Values.enabled (ne .Values.image.digest "sha256:0000000000000000000000000000000000000000000000000000000000000000") }}true{{ end }}
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
