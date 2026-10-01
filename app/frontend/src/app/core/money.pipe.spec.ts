import { formatCents } from './money.pipe';

// Maintainer smoke test: proves the unit-test runner works. Not a model answer for A-04.
describe('formatCents', () => {
  it('formats cents as Brazilian reais', () => {
    expect(formatCents(45990)).toBe('R$459.90');
  });
});
