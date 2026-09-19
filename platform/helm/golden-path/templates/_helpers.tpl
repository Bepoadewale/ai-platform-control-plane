{{- define "golden-path.fullname" -}}{{ .Values.name | trunc 63 | trimSuffix "-" }}{{- end }}
