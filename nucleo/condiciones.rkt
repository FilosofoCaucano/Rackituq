#lang racket

(provide (all-defined-out))

;; ----- EVALUACIÓN DE CONDICIONES -----

;; Función para evaluar condiciones
(define (evaluar-condicion x operador y)
  (cond
    [(string=? operador ">") (> x y)]
    [(string=? operador "<") (< x y)]
    [(string=? operador "==") (= x y)]
    [(string=? operador "!=") (not (= x y))]
    [(string=? operador ">=") (>= x y)]
    [(string=? operador "<=") (<= x y)]
    [(string=? operador "and") (and x y)]
    [(string=? operador "or") (or x y)]
    [(string=? operador "not") (not x)]
    [else #f]))
