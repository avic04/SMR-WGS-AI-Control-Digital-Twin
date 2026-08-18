# SMR-WGS-AI-Control-Digital-Twin
AI-supervised process control and economic optimization of an SMR-WGS hydrogen production process using PID, fuzzy PID, ANN and genetic algorithms.
# SMR-WGS AI Control Digital Twin

## Overview

A control-oriented digital twin of a steam methane reforming
(SMR) process integrated with water-gas shift (WGS) and flash
separation.

The framework compares:

- Conventional PID
- Fuzzy gain-scheduled PID
- ANN-supervised fuzzy PID

under multiple process disturbances.

A genetic algorithm is used for supervisory operating-point
optimization, while an ANN provides a fast surrogate for
real-time supervisory decisions.

---

## Process Architecture

CH4 + H2O
    |
    v
SMR PFR
    |
    v
WGS CSTR
    |
    v
Flash Separator
    |
    +---- H2-rich vapor
    |
    +---- CO2/CO/CH4/H2O stream

---

## Control Architecture

Economic Layer
      |
      v
     GA
      |
      v
 ANN Surrogate
      |
      v
Optimal Temperature Setpoints
      |
      v
Fuzzy PID
      |
      v
SMR / WGS PID Controllers
      |
      v
Process Digital Twin

---

## Features

- Mechanistic SMR PFR model
- WGS CSTR model
- Flash separation
- PID control
- Fuzzy PID gain scheduling
- ANN supervisory control
- GA-based operating-point optimization
- Economic objective function
- INR-based economics
- Feed disturbances
- Feed-temperature disturbances
- Kinetic disturbances
- Heat-transfer disturbances
- Combined disturbances
- Automated mass-balance validation
- Constraint validation
- Monte-Carlo robustness analysis
- Pareto operating-point analysis
- KPI dashboard

---

## Performance Metrics

The framework evaluates:

- RMSE
- IAE
- ISE
- settling time
- H2 production
- H2 purity
- specific energy consumption
- economic profit
- actuator saturation
- constraint violations
- robustness/pass rate

---

## Requirements

MATLAB

The core implementation is designed to operate using base MATLAB.
No external optimization, fuzzy-logic or deep-learning toolbox is
required for the custom GA/ANN implementation.

---

## How to Run

1. Clone the repository.
2. Open MATLAB.
3. Navigate to the repository.
4. Run:

SMR_WGS_AI_Control

5. The simulation generates controller-performance plots,
validation results and KPI summaries.

---

## Model Scope

This is a control-oriented reduced-order digital twin.

The current kinetic, thermodynamic and economic parameters are
prototype values and should not be interpreted as plant-validated
data.

Future work includes:

- literature-validated kinetics
- Aspen Plus validation
- spatially discretized PFR
- higher-fidelity thermodynamics
- experimental validation
- real-time hardware/software integration

---

## Project Motivation

The objective is to investigate whether AI-assisted supervisory
control can improve the trade-off between:

Hydrogen production
        vs.
Energy consumption
        vs.
Economic profit
        vs.
Process constraints

while retaining conventional PID control as the regulatory layer.
