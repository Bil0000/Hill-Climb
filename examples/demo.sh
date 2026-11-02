#!/usr/bin/env bash
set -euo pipefail

CLIMB="$(cd "$(dirname "$0")/.." && pwd)/skills/hill-climb/scripts/climb.py"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
export HILL_CLIMB_HOME="$work/home"
cd "$work"
git init -q -b main shop && cd shop
git config user.email demo@example.com
git config user.name Demo
git config commit.gpgsign false

cat > cart.py <<'PY'
def total(prices, coupon=None):
    subtotal = prices[0] + sum(prices[1:])
    if coupon == "VIP":
        subtotal = subtotal / 2
    return subtotal
PY
cat > test_old.py <<'PY'
import unittest
from cart import total

class Old(unittest.TestCase):
    def test_sum(self):
        self.assertEqual(total([10, 20]), 30)
    def test_vip_pays_half(self):
        self.assertEqual(total([10, 20], "VIP"), 15)
PY
echo '__pycache__/' > .gitignore
git add . && git commit -qm "shop"

mkdir spec
cat > spec/test_cart.py <<'PY'
import unittest
from cart import total

class Findings(unittest.TestCase):
    def test_empty_cart_is_zero(self):
        self.assertEqual(total([]), 0)
    def test_save10_rounds_to_cents(self):
        self.assertEqual(total([19.99, 5], "SAVE10"), 22.49)
    def test_codes_ignore_case(self):
        self.assertEqual(total([100], "save10"), 90)
    def test_never_below_zero(self):
        self.assertEqual(total([5], "TAKE100"), 0)
PY

say() { printf '\n\033[1m$ %s\033[0m\n' "$*"; }
climb() { say "climb.py $*"; python3 "$CLIMB" "$@" || true; }
edit() { printf '\n\033[2m# agent: %s\033[0m\n' "$*"; }

climb init cart-audit --goal "fix every cart finding" \
  --check "python3 -m unittest discover -s spec" --score 'failures=(\d+)|errors=(\d+)' \
  --direction min --target 0 --guard "python3 -m unittest test_old" --lock spec

edit "start the sum at zero"
sed -i.bak 's/prices\[0\] + sum(prices\[1:\])/sum(prices)/' cart.py && rm cart.py.bak
climb try "start the sum at zero"

edit "round every total to whole numbers"
sed -i.bak 's/return subtotal/return round(subtotal)/' cart.py && rm cart.py.bak
climb try "round every total to whole numbers"

edit "replace the VIP check with a coupon table, and forget VIP"
cat > cart.py <<'PY'
OFF = {"SAVE10": 0.10}

def total(prices, coupon=None):
    subtotal = sum(prices) * (1 - OFF.get((coupon or "").upper(), 0))
    return round(subtotal, 2)
PY
climb try "coupon table"

edit "make the test expect what the code returns"
sed -i.bak 's/22.49)/24.99)/' spec/test_cart.py && rm spec/test_cart.py.bak
climb try "fix the test"
git checkout -q -- spec

edit "coupon table that keeps VIP"
cat > cart.py <<'PY'
OFF = {"SAVE10": 0.10, "VIP": 0.50}

def total(prices, coupon=None):
    subtotal = sum(prices) * (1 - OFF.get((coupon or "").upper(), 0))
    return round(subtotal, 2)
PY
climb try "coupon table, VIP kept"

edit "add TAKE100 and never go below zero"
cat > cart.py <<'PY'
OFF = {"SAVE10": 0.10, "VIP": 0.50}
TAKE = {"TAKE100": 100}

def total(prices, coupon=None):
    code = (coupon or "").upper()
    subtotal = sum(prices) * (1 - OFF.get(code, 0)) - TAKE.get(code, 0)
    return max(0, round(subtotal, 2))
PY
climb try "TAKE100, floor at zero"

climb status
git log --oneline
