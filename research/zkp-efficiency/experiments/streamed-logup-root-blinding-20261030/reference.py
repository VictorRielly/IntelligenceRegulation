"""Independent polynomial-basis field and histogram/direct rational oracle."""
from collections import Counter


class RefField:
    def __init__(self, modulus, nonresidue):
        self.p, self.nr = modulus, nonresidue

    def product(self, x, y):
        coefficients = [0, 0, 0]
        for i in range(2):
            for j in range(2):
                coefficients[i+j] += x[i]*y[j]
        return ((coefficients[0]+self.nr*coefficients[2]) % self.p,
                coefficients[1] % self.p)

    def plus(self, x, y):
        return tuple((a+b) % self.p for a, b in zip(x, y))

    def exponent(self, x, power):
        # Left-to-right exponentiation, unlike the candidate implementation.
        value = (1, 0)
        for bit in bin(power)[2:]:
            value = self.product(value, value)
            if bit == '1':
                value = self.product(value, x)
        return value

    def inverse(self, x):
        if x == (0, 0):
            raise ValueError('reference division by zero')
        return self.exponent(x, self.p*self.p-2)

    def histogram_root(self, values, alpha, inverses=None):
        counts = Counter(values)
        denominator, rational_sum = (1, 0), (0, 0)
        for v, count in counts.items():
            den = ((alpha[0]-v) % self.p, alpha[1])
            inv = inverses[v] if inverses is not None else self.inverse(den)
            denominator = self.product(denominator, self.exponent(den, count))
            rational_sum = self.plus(rational_sum, self.product((count % self.p, 0), inv))
        return self.product(denominator, rational_sum), denominator

    def direct_root(self, fractions):
        # Sequential fraction addition; never follows the binary tree.
        n, d = (0, 0), (1, 0)
        for a, b in fractions:
            n = self.plus(self.product(n, b), self.product(a, d))
            d = self.product(d, b)
        return n, d

    def ordered_mle(self, values, point):
        total = (0, 0)
        for index, value in enumerate(values):
            weight = (1, 0)
            for bit, r in enumerate(point):
                factor = r if (index >> bit) & 1 else ((1-r[0]) % self.p, -r[1] % self.p)
                weight = self.product(weight, factor)
            total = self.plus(total, self.product((value % self.p, 0), weight))
        return total
