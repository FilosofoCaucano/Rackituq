#lang racket

(provide (all-defined-out))

;; ----- ESTRUCTURAS DE DATOS PRINCIPALES -----

;; Tabla de almacenamiento de variables con gestión de tipos
(define variables (make-hash))
(define tipos (make-hash))

;; Tabla de almacenamiento de funciones
(define funciones (make-hash))

;; Tabla para módulos importados
(define modulos (make-hash))

;; Caché para optimización de memoria
(define memoria-cache (make-hash))
