{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load({
  serviceWorkerSettings: {serviceWorkerVersion: {{flutter_service_worker_version}}},
  config: {hostElement: document.getElementById('sanad-app-host')},
  onEntrypointLoaded: async function(engineInitializer) {
    try {
      const appRunner = await engineInitializer.initializeEngine({hostElement: document.getElementById('sanad-app-host')});
      await appRunner.runApp();
      requestAnimationFrame(() => requestAnimationFrame(() => window.sanadEngineReady()));
    } catch (_) { window.sanadEngineError(); }
  }
}).catch(() => window.sanadEngineError());
