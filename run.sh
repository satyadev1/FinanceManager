#!/usr/bin/env bash
# Fin Manager – create platforms (if needed), get deps, run app (web).
set -e
cd "$(dirname "$0")"

if ! command -v flutter &>/dev/null; then
  echo "Flutter is not in PATH. Install from https://docs.flutter.dev/get-started/install"
  echo "Then run: ./run.sh"
  exit 1
fi

if [ ! -d "android" ] || [ ! -d "web" ]; then
  echo "Creating Android and Web platform folders..."
  flutter create . --project-name finance_manager
fi

echo "Getting dependencies..."
flutter pub get

echo "Running app (Chrome)..."
flutter run -d chrome
