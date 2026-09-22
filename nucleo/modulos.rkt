#lang racket

(require "estado.rkt")
(provide (all-defined-out))

;; ----- SOPORTE PARA MÓDULOS -----

;; Importar un módulo
(define (importar-modulo ruta)
  (if (file-exists? ruta)
      (let ([mod-env (make-hash)]
            ;; Cada módulo se evalúa en su propio namespace con Racket base
            [ns (make-base-namespace)])
        (with-input-from-file ruta
          (lambda ()
            (let loop ([expr (read)])
              (unless (eof-object? expr)
                (eval expr ns)
                ;; Lo que el módulo define pasa a las variables de Rackituq
                (match expr
                  [`(define ,(? symbol? nombre) ,_)
                   (let ([valor (eval nombre ns)])
                     (hash-set! mod-env (symbol->string nombre) valor)
                     (hash-set! variables (symbol->string nombre) valor))]
                  [_ (void)])
                (loop (read))))))
        (hash-set! modulos (if (path? ruta) (path->string ruta) ruta) mod-env)
        (format "Módulo ~a importado correctamente" ruta))
      (format "Error: No se pudo encontrar el módulo ~a" ruta)))

;; Exportar definiciones a un módulo
(define (exportar-a-modulo nombres ruta)
  (with-output-to-file ruta #:exists 'replace
    (lambda ()
      (for ([nombre nombres])
        (cond
          ;; ~s con comilla para que listas y textos se puedan volver a leer
          [(hash-has-key? variables nombre)
           (printf "(define ~a '~s)\n" nombre (hash-ref variables nombre))]
          ;; Una función compilada no tiene forma de texto
          [(hash-has-key? funciones nombre)
           (printf ";; ~a es una función: no se puede exportar como texto\n" nombre)]
          [else
           (printf ";; Error: ~a no está definido\n" nombre)]))))
  (format "Definiciones exportadas a ~a" ruta))
