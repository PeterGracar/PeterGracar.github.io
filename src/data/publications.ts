export type PublicationItem = {
  title: string;
  pdfUrl?: string;
  detailUrl?: string;
  venue: string;
  yearLabel: string;
  coauthors: string;
  note?: string;
};

export type PublicationSection = {
  title: string;
  items: PublicationItem[];
};

export const publicationSections: PublicationSection[] = [
  {
    title: 'Submitted papers / Preprints',
    items: [
      {
        title: 'Chemical distance in the Poisson Boolean model with regularly varying diameters',
        pdfUrl: 'https://arxiv.org/pdf/2503.18577',
        detailUrl: 'https://arxiv.org/abs/2503.18577',
        venue: 'arXiv:2503.18577',
        yearLabel: '2025',
        coauthors: 'with Marilyn Korfhage'
      },
      {
        title: 'Robustness in the Poisson Boolean model with convex grains',
        pdfUrl: 'https://arxiv.org/pdf/2410.13366',
        detailUrl: 'https://arxiv.org/abs/2410.13366',
        venue: 'arXiv:2410.13366',
        yearLabel: '2024',
        coauthors: 'with Marilyn Korfhage and Peter Mörters'
      },
      {
        title: 'Geometric scale-free random graphs on mobile vertices: broadcast and percolation times',
        pdfUrl: 'https://arxiv.org/pdf/2404.15124',
        detailUrl: 'https://arxiv.org/abs/2404.15124',
        venue: 'arXiv:2404.15124',
        yearLabel: '2024',
        coauthors: 'with Arne Grauer'
      }
    ]
  },
  {
    title: 'Published / Accepted papers',
    items: [
      {
        title: 'Finiteness of the percolation threshold for inhomogeneous long-range models in one dimension',
        pdfUrl: 'https://projecteuclid.org/journalArticle/Download?urlId=10.1214%2F25-EJP1399',
        detailUrl:
          'https://projecteuclid.org/journals/electronic-journal-of-probability/volume-30/issue-none/Finiteness-of-the-percolation-threshold-for-inhomogeneous-long-range-models/10.1214/25-EJP1399.full',
        venue: 'Electronic Journal of Probability, 30: 1-29',
        yearLabel: '2025',
        coauthors: 'with Lukas Lüchtrath and Christian Mönch'
      },
      {
        title: 'Lipschitz cutset for fractal graphs and applications to the spread of infections',
        pdfUrl:
          'https://www.e-publications.org/ims/submission/AIHP/user/submissionFile/62496?confirm=4f341d03',
        detailUrl:
          'https://imstat.org/journals-and-publications/annales-de-linstitut-henri-poincare/annales-de-linstitut-henri-poincare-accepted-papers/',
        venue: 'Annales de l’Institut Henri Poincaré, Probabilités et Statistiques',
        yearLabel: 'to appear',
        coauthors: 'with Alexander Drewitz and Gioele Gallo'
      },
      {
        title: 'The contact process on scale-free geometric random graphs',
        pdfUrl: 'https://doi.org/10.1016/j.spa.2024.104360',
        detailUrl: 'https://doi.org/10.1016/j.spa.2024.104360',
        venue: 'Stochastic Processes and their Applications, Volume 173: 104360',
        yearLabel: '2024',
        coauthors: 'with Arne Grauer'
      },
      {
        title: 'The Emergence of a Giant Component in One-Dimensional Inhomogeneous Networks with Long-Range Effects',
        pdfUrl: '/papers/waw2023.pdf',
        detailUrl: 'https://link.springer.com/chapter/10.1007/978-3-031-32296-9_2',
        venue: 'Algorithms and Models for the Web Graph, WAW 2023: 19-35',
        yearLabel: '2023',
        coauthors: 'with Lukas Lüchtrath and Christian Mönch'
      },
      {
        title: 'Chemical distance in geometric random graphs with long edges and scale-free degree distribution',
        pdfUrl: 'https://link.springer.com/content/pdf/10.1007/s00220-022-04445-3.pdf',
        detailUrl: 'https://link.springer.com/article/10.1007/s00220-022-04445-3',
        venue: 'Communications in Mathematical Physics, 395: 859-906',
        yearLabel: '2022',
        coauthors: 'with Arne Grauer and Peter Mörters'
      },
      {
        title: 'Recurrence versus Transience for Weight-Dependent Random Connection Models',
        pdfUrl: 'https://projecteuclid.org/journalArticle/Download?urlId=10.1214%2F22-EJP748',
        detailUrl:
          'https://projecteuclid.org/journals/electronic-journal-of-probability/volume-27/issue-none/Recurrence-versus-transience-for-weight-dependent-random-connection-models/10.1214/22-EJP748.full',
        venue: 'Electronic Journal of Probability, 27: 1-31',
        yearLabel: '2022',
        coauthors: 'with Markus Heydenreich, Christian Mönch and Peter Mörters'
      },
      {
        title: 'Percolation phase transition in weight-dependent random connection models',
        pdfUrl:
          'https://www.cambridge.org/core/services/aop-cambridge-core/content/view/7B85863F4E9E3FB24BA77F538D1A871A/S0001867821000136a.pdf/percolation-phase-transition-in-weight-dependent-random-connection-models.pdf',
        detailUrl:
          'https://www.cambridge.org/core/journals/advances-in-applied-probability/article/abs/percolation-phase-transition-in-weightdependent-random-connection-models/7B85863F4E9E3FB24BA77F538D1A871A',
        venue: 'Advances in Applied Probability, 53(4): 1090-1114',
        yearLabel: '2021',
        coauthors: 'with Lukas Lüchtrath and Peter Mörters',
        note:
          'Part of the June 2025 Applied Probability Collection on Phase Transitions.'
      },
      {
        title: 'Transience Versus Recurrence for Scale-Free Spatial Networks',
        pdfUrl: '/papers/waw2020.pdf',
        detailUrl: 'https://link.springer.com/chapter/10.1007/978-3-030-48478-1_7',
        venue: 'Algorithms and Models for the Web Graph, WAW 2020: 96-110',
        yearLabel: '2020',
        coauthors: 'with Markus Heydenreich, Christian Mönch and Peter Mörters'
      },
      {
        title: 'The age-dependent random connection model',
        pdfUrl: 'https://link.springer.com/content/pdf/10.1007/s11134-019-09625-y.pdf',
        detailUrl: 'https://link.springer.com/article/10.1007/s11134-019-09625-y',
        venue: 'Queueing Systems, 93: 309-331',
        yearLabel: '2019',
        coauthors: 'with Arne Grauer, Lukas Lüchtrath and Peter Mörters'
      },
      {
        title: 'Multi-scale Lipschitz percolation of increasing events for Poisson random walks',
        pdfUrl: 'https://projecteuclid.org/journalArticle/Download?urlId=10.1214%2F18-AAP1420',
        detailUrl: 'https://projecteuclid.org/euclid.aoap/1544000432',
        venue: 'Annals of Applied Probability, 29: 376-433',
        yearLabel: '2019',
        coauthors: 'with Alexandre Stauffer'
      },
      {
        title: 'Random walks in random conductances: decoupling and spread of infection',
        pdfUrl: '/papers/SPA129.pdf',
        detailUrl: 'https://doi.org/10.1016/j.spa.2018.09.016',
        venue: 'Stochastic Processes and their Applications, 129: 3547-3569',
        yearLabel: '2019',
        coauthors: 'with Alexandre Stauffer'
      },
      {
        title: 'Percolation of Lipschitz surface and tight bounds on the spread of information among mobile agents',
        pdfUrl: 'https://arxiv.org/abs/1806.01140',
        detailUrl: 'https://drops.dagstuhl.de/opus/volltexte/2018/9443/',
        venue: 'APPROX-RANDOM 2018, 39: 1-17',
        yearLabel: '2018',
        coauthors: 'with Alexandre Stauffer'
      }
    ]
  }
];

export type NamedLink = {
  name: string;
  url: string;
};

export type TalkItem = {
  title: string;
  url: string;
  location: string;
};

export const coauthors: NamedLink[] = [
  { name: 'Alexander Drewitz', url: 'https://www.mi.uni-koeln.de/~drewitz/' },
  { name: 'Gioele Gallo', url: 'https://www.linkedin.com/in/gioele-gallo/' },
  { name: 'Arne Grauer', url: 'https://sites.google.com/view/arnegrauer/home' },
  {
    name: 'Markus Heydenreich',
    url: 'https://www.uni-augsburg.de/de/fakultaet/mntf/math/prof/sto/hey/'
  },
  { name: 'Marilyn Korfhage', url: 'https://sites.google.com/view/marilyn-korfhage' },
  { name: 'Lukas Lüchtrath', url: 'https://wias-berlin.de/people/luechtrath/?lang=1' },
  { name: 'Christian Mönch', url: 'https://sites.google.com/view/cmoench' },
  { name: 'Peter Mörters', url: 'https://www.mi.uni-koeln.de/~moerters/' },
  {
    name: 'Alexandre Stauffer',
    url: 'https://sites.google.com/site/alexandrestauffer/home'
  }
];

export const talks: TalkItem[] = [
  {
    title: 'Long-range phenomena in Percolation',
    url: 'https://sites.google.com/view/long-range-percolation-cologne/',
    location: 'Cologne, Germany'
  },
  {
    title: 'Stochastic Geometry in Action',
    url: 'https://sites.google.com/view/stochasticgeometryinaction/home',
    location: 'Bath, UK'
  },
  {
    title: 'Dynamic spatial random systems',
    url: 'https://www.wias-berlin.de/workshops/DYSPARS24/#programme-anchor',
    location: 'Berlin, Germany'
  },
  {
    title: 'Recent Trends in Spatial Stochastic Processes',
    url: 'https://www.eurandom.tue.nl/event/workshop-recent-trends-in-spatial-stochastic-processes/',
    location: 'Eindhoven, Netherlands'
  },
  {
    title: 'Random Geometric Systems: First Annual Conference',
    url: 'https://www.wias-berlin.de/workshops/RaGeSys/',
    location: 'Berlin, Germany'
  },
  {
    title: 'Spatial Networks and Percolation',
    url: 'https://www.mfo.de/occasion/2103/www_view',
    location: 'Oberwolfach, Germany'
  },
  {
    title: 'YEP XV: Information Diffusion on Random Networks',
    url: 'https://www.eurandom.tue.nl/event/yep-xv-information-diffusion-on-random-networks/',
    location: 'Eindhoven, Netherlands'
  },
  {
    title: 'APPROX/RANDOM 2018',
    url: 'https://cui.unige.ch/tcs/random-approx/2018/index.php',
    location: 'Princeton, USA'
  },
  {
    title: 'Strongly Correlated Random Interacting Processes',
    url: 'https://www.mfo.de/occasion/1805/www_view',
    location: 'Oberwolfach, Germany'
  }
];
