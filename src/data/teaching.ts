export type ModuleItem = {
  code: string;
  title: string;
  role: string;
};

export const modules: ModuleItem[] = [
  { code: 'MATH5320M', title: 'Discrete Time Finance', role: 'Module leader' },
  { code: 'MATH5004M', title: 'MMath Year 4 Project', role: 'Supervisor' },
  { code: 'MATH3001', title: 'Project in Mathematics', role: 'Supervisor' },
  { code: 'MATH1700', title: 'Probability and Statistics', role: 'Tutor' }
];
