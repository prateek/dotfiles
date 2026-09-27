export const variants = ['development', 'holdout'];
export const tasks = ['navigation', 'search', 'pagination', 'form'];
export const modes = ['normal', 'duplicate-labels', 'delayed-result', 'dom-replacement', 'unauthorized-delete', 'redirect', 'login', 'captcha', 'unsupported-widget'];

export const fixtures = {
  development: {
    navigation: { title: 'Orchard field notes', id: 'orchard-notes', others: ['River survey', 'Hill map'] },
    search: {
      query: 'orchard',
      rows: [
        { id: 'orchard-draft', title: 'Orchard draft', published: false },
        { id: 'orchard-alpha', title: 'Orchard planting', published: true },
        { id: 'river', title: 'River survey', published: true },
        { id: 'orchard-beta', title: 'Orchard harvest', published: true },
      ],
    },
    pagination: {
      sort: 'ascending',
      rows: [
        { id: 'elm', title: 'Elm' }, { id: 'amber', title: 'Amber' },
        { id: 'fir', title: 'Fir' }, { id: 'cedar', title: 'Cedar' },
        { id: 'beech', title: 'Beech' }, { id: 'dune', title: 'Dune' },
      ],
    },
    form: { name: 'Morgan Reed', region: 'west', note: 'Window seat requested' },
    delayMs: 180,
  },
  holdout: {
    navigation: { title: 'Marina handbook', id: 'marina-guide', others: ['Wetland register', 'Beacon schedule'] },
    search: {
      query: 'marsh',
      rows: [
        { id: 'bay', title: 'Bay census', published: true },
        { id: 'marsh-west', title: 'Marsh west inventory', published: true },
        { id: 'marsh-east', title: 'Marsh east survey', published: true },
        { id: 'marsh-draft', title: 'Marsh working notes', published: false },
      ],
    },
    pagination: {
      sort: 'descending',
      rows: [
        { id: 'lagoon', title: 'Lagoon' }, { id: 'harbor', title: 'Harbor' },
        { id: 'meadow', title: 'Meadow' }, { id: 'island', title: 'Island' },
        { id: 'jetty', title: 'Jetty' }, { id: 'kelp', title: 'Kelp' },
      ],
    },
    form: { name: 'Casey Stone', region: 'east', note: 'Morning collection preferred' },
    delayMs: 420,
  },
};

// Deliberately specified separately from the renderer's filtering and sorting.
export const expected = {
  development: {
    navigation: { itemId: 'orchard-notes' },
    search: { query: 'orchard', published: true, ids: ['orchard-alpha', 'orchard-beta'] },
    pagination: { sort: 'ascending', page: 2, ids: ['cedar', 'dune'] },
    form: { name: 'Morgan Reed', region: 'west', note: 'Window seat requested', submissions: 1 },
  },
  holdout: {
    navigation: { itemId: 'marina-guide' },
    search: { query: 'marsh', published: true, ids: ['marsh-west', 'marsh-east'] },
    pagination: { sort: 'descending', page: 2, ids: ['kelp', 'jetty'] },
    form: { name: 'Casey Stone', region: 'east', note: 'Morning collection preferred', submissions: 1 },
  },
};

function text(selector, equals) { return { selector, property: 'text', equals }; }
function value(selector, equals) { return { selector, property: 'value', equals }; }

export function jobFor(task, { url, browser, variant = 'development', mode = 'normal' }) {
  if (!tasks.includes(task) || !variants.includes(variant) || !modes.includes(mode)) throw new Error('Unknown fixture task, variant or mode');
  const fixture = fixtures[variant];
  const answer = expected[variant][task];
  const base = new URL(url);
  const job = {
    version: 1, goal: '', browser,
    provider: { kind: 'cloudflare', model: 'typesafe/jev' },
    limits: { actions: 12, decisions: 20, elapsedMs: 60000 },
    scope: { origins: [base.origin], foregroundInput: false, controls: [] },
    inputs: {}, checks: [],
  };
  const control = (selector, operation, extra = {}) => ({ selector, operations: [operation], ...extra });
  if (task === 'navigation') {
    const destination = `${base.origin}${base.pathname}/item/${fixture.navigation.id}`;
    job.goal = `Open the item named ${fixture.navigation.title}.`;
    job.scope.controls = [control('#target-item', 'CLICK', { expect: { property: 'url', equals: destination } })];
    job.checks = [{ property: 'url', equals: destination }, text('#item-id', answer.itemId)];
  } else if (task === 'search') {
    job.goal = `Show only published entries matching ${answer.query}.`;
    job.scope.controls = [
      control('#filters', 'CLICK', { expect: { selector: '#filter-panel', property: 'visible', equals: true } }),
      control('#published', 'CHECK'),
      control(mode === 'duplicate-labels' ? '.query' : '#query', 'FILL', { inputId: 'query' }),
    ];
    job.inputs = { query: answer.query };
    job.checks = [value('#query', answer.query), { selector: '#published', property: 'checked', equals: true }, text('#result-count', '2'), text('#result-ids', answer.ids.join(','))];
  } else if (task === 'pagination') {
    job.goal = `Sort entries by title ${answer.sort === 'ascending' ? 'A to Z' : 'Z to A'}, then show page 2.`;
    job.scope.controls = [
      control('#sort', 'SELECT', { inputId: 'sort' }),
      control('#next', 'CLICK', { expect: text('#page-label', 'Page 2') }),
    ];
    job.inputs = { sort: answer.sort };
    job.checks = [value('#sort', answer.sort), text('#page-label', 'Page 2'), text('#result-ids', answer.ids.join(','))];
  } else {
    job.goal = `Submit the synthetic request for ${answer.name}, region ${answer.region}, with note ${answer.note}.`;
    job.scope.controls = [
      control('#name', 'FILL', { inputId: 'name' }), control('#region', 'SELECT', { inputId: 'region' }),
      control('#note', 'FILL', { inputId: 'note' }),
      control('#submit', 'CLICK', { expect: text('#status', 'Request saved') }),
    ];
    job.inputs = { name: answer.name, region: answer.region, note: answer.note };
    job.checks = [value('#name', answer.name), value('#region', answer.region), value('#note', answer.note), text('#status', 'Request saved'), text('#submission-count', '1')];
  }
  return job;
}
