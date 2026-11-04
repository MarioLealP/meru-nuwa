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

{{/* The pod spec the Deployment and the CronJob share (job.schedule set = a CronJob: no port, no probes - a job
runs to its end, rule 6 checks long-running workloads only). Every other rule holds for both. */}}
{{- define "nuwa-app.podSpec" -}}
serviceAccountName: {{ .Values.name }}
automountServiceAccountToken: false
# Pod Security "restricted" (rule 4), spelled out so the pod passes it whatever the image does.
securityContext:
  runAsNonRoot: true
  runAsUser: {{ .Values.runAsUser }}
  runAsGroup: {{ .Values.runAsUser }}
  fsGroup: {{ .Values.runAsUser }}
  seccompProfile:
    type: RuntimeDefault
containers:
  - name: app
    image: {{ include "nuwa-app.image" . }}
    {{- with .Values.command }}
    command:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with .Values.args }}
    args:
      {{- toYaml . | nindent 6 }}
    {{- end }}
{{- if not .Values.job.schedule }}
    ports:
      - name: http
        containerPort: {{ .Values.port }}
      {{- range .Values.extraPorts }}
      - name: {{ .name }}
        containerPort: {{ .port }}
      {{- end }}
{{- end }}
    env:
      - name: PORT
        value: {{ .Values.port | quote }}
      {{- if .Values.otel.enabled }}
      - name: OTEL_SERVICE_NAME
        value: {{ .Values.name }}
      - name: OTEL_RESOURCE_ATTRIBUTES
        value: service.namespace={{ .Release.Namespace }},meru.owner={{ .Values.owner }}
      {{- with .Values.otel.endpoint }}
      - name: OTEL_EXPORTER_OTLP_ENDPOINT
        value: {{ . | quote }}
      {{- end }}
      {{- end }}
      {{- range $key, $value := .Values.env }}
      - name: {{ $key }}
        value: {{ $value | quote }}
      {{- end }}
      {{- include "nuwa-app.secretEnv" .Values.secretEnv | nindent 6 }}
{{- if not .Values.job.schedule }}
    # Rule 6: the platform knows when the app is up (startup), alive (liveness) and serving (readiness).
    startupProbe:
      httpGet:
        path: {{ .Values.heartbeat.path }}
        port: http
        {{- if eq .Values.heartbeat.scheme "HTTPS" }}
        scheme: HTTPS
        {{- end }}
      periodSeconds: 2
      timeoutSeconds: {{ .Values.heartbeat.timeoutSeconds }}
      failureThreshold: {{ .Values.heartbeat.startupFailureThreshold }}
    livenessProbe:
      httpGet:
        path: {{ .Values.heartbeat.path }}
        port: http
        {{- if eq .Values.heartbeat.scheme "HTTPS" }}
        scheme: HTTPS
        {{- end }}
      periodSeconds: {{ .Values.heartbeat.periodSeconds }}
      timeoutSeconds: {{ .Values.heartbeat.timeoutSeconds }}
      failureThreshold: {{ .Values.heartbeat.failureThreshold }}
    readinessProbe:
      httpGet:
        path: {{ .Values.heartbeat.readyPath | default .Values.heartbeat.path }}
        port: http
        {{- if eq .Values.heartbeat.scheme "HTTPS" }}
        scheme: HTTPS
        {{- end }}
      periodSeconds: {{ .Values.heartbeat.periodSeconds }}
      timeoutSeconds: {{ .Values.heartbeat.timeoutSeconds }}
      failureThreshold: 1
{{- end }}
    # Rule 5.
    resources:
      {{- toYaml .Values.resources | nindent 6 }}
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: [ALL]
    {{- if or .Values.tmp.enabled .Values.persistence .Values.configMaps .Values.certificate.enabled .Values.openbaoLogin.enabled .Values.kubernetesApi.enabled }}
    volumeMounts:
      {{- if .Values.tmp.enabled }}
      - name: tmp
        mountPath: /tmp
      {{- end }}
      {{- range .Values.persistence }}
      - name: {{ .name }}
        mountPath: {{ .mountPath }}
      {{- end }}
      {{- range .Values.configMaps }}
      - name: cm-{{ .name }}
        mountPath: {{ .mountPath }}
        readOnly: true
      {{- end }}
      {{- if .Values.certificate.enabled }}
      - name: tls
        mountPath: {{ .Values.certificate.mountPath }}
        readOnly: true
      {{- end }}
      {{- if .Values.openbaoLogin.enabled }}
      - name: openbao
        mountPath: {{ .Values.openbaoLogin.mountPath }}
        readOnly: true
      {{- end }}
      {{- if .Values.kubernetesApi.enabled }}
      - name: kubernetes-api
        mountPath: {{ .Values.kubernetesApi.mountPath }}
        readOnly: true
      {{- end }}
      {{- if .Values.authentikLogin.enabled }}
      - name: authentik
        mountPath: {{ .Values.authentikLogin.mountPath }}
        readOnly: true
      {{- end }}
    {{- end }}
{{- if or .Values.tmp.enabled .Values.persistence .Values.configMaps .Values.certificate.enabled .Values.openbaoLogin.enabled .Values.kubernetesApi.enabled .Values.authentikLogin.enabled }}
volumes:
  {{- if .Values.tmp.enabled }}
  - name: tmp
    emptyDir:
      sizeLimit: {{ .Values.tmp.sizeLimit }}
  {{- end }}
  {{- range .Values.persistence }}
  - name: {{ .name }}
    persistentVolumeClaim:
      claimName: {{ $.Values.name }}-{{ .name }}
  {{- end }}
  {{- range .Values.configMaps }}
  - name: cm-{{ .name }}
    configMap:
      name: {{ .name }}
      optional: true # made outside the chart; the pod starts before the first one exists
  {{- end }}
  {{- if .Values.certificate.enabled }}
  - name: tls
    secret:
      secretName: {{ .Values.name }}-tls
      defaultMode: 0400
  {{- end }}
  {{- if .Values.openbaoLogin.enabled }}
  - name: openbao
    projected:
      defaultMode: 0400
      sources:
        - serviceAccountToken:
            audience: openbao
            expirationSeconds: 600
            path: token
        - configMap:
            name: {{ .Values.name }}-openbao-ca
            items:
              - key: ca.crt
                path: ca.crt
  {{- end }}
  {{- if .Values.authentikLogin.enabled }}
  - name: authentik
    projected:
      defaultMode: 0400
      sources:
        - serviceAccountToken:
            audience: authentik
            expirationSeconds: 3600
            path: token
  {{- end }}
  {{- if .Values.kubernetesApi.enabled }}
  - name: kubernetes-api
    projected:
      defaultMode: 0400
      sources:
        - serviceAccountToken: # no audience: the API server's own
            expirationSeconds: 600
            path: token
        - configMap:
            name: kube-root-ca.crt # every namespace has it
            items:
              - key: ca.crt
                path: ca.crt
  {{- end }}
{{- end }}
{{- end }}
