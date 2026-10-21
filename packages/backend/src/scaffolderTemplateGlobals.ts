import {
  coreServices,
  createBackendModule,
} from '@backstage/backend-plugin-api';
import { scaffolderTemplatingExtensionPoint } from '@backstage/plugin-scaffolder-node/alpha';

export default createBackendModule({
  pluginId: 'scaffolder',
  moduleId: 'portal-template-globals',
  register(reg) {
    reg.registerInit({
      deps: {
        config: coreServices.rootConfig,
        templating: scaffolderTemplatingExtensionPoint,
      },
      async init({ config, templating }) {
        templating.addTemplateGlobals({
          backstageBaseUrl: config.getString('app.baseUrl').replace(/\/+$/, ''),
        });
      },
    });
  },
});
