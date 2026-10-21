import { createBackendModule } from '@backstage/backend-plugin-api';
import { ConfigReader } from '@backstage/config';
import './scaffolderTemplateGlobals';

jest.mock('@backstage/backend-plugin-api', () => ({
  ...jest.requireActual('@backstage/backend-plugin-api'),
  createBackendModule: jest.fn(),
}));

describe('scaffolder template globals', () => {
  const module = jest.mocked(createBackendModule).mock.calls[0][0];

  async function initialize(config: ConfigReader) {
    const registerInit = jest.fn();
    const addTemplateGlobals = jest.fn();
    module.register({
      registerInit,
      registerExtensionPoint: jest.fn(),
    });
    await registerInit.mock.calls[0][0].init({
      config,
      templating: { addTemplateGlobals },
    });
    return addTemplateGlobals;
  }

  it.each([
    ['https://backstage.example.com', 'https://backstage.example.com'],
    ['http://localhost:3000/', 'http://localhost:3000'],
    ['https://example.com/portal///', 'https://example.com/portal'],
  ])('exposes the configured base URL %s', async (baseUrl, expected) => {
    const addTemplateGlobals = await initialize(
      new ConfigReader({ app: { baseUrl } }),
    );

    expect(module.pluginId).toBe('scaffolder');
    expect(addTemplateGlobals).toHaveBeenCalledWith({
      backstageBaseUrl: expected,
    });
  });

  it('fails explicitly when app.baseUrl is missing', async () => {
    await expect(initialize(new ConfigReader({}))).rejects.toThrow(
      'app.baseUrl',
    );
  });
});
