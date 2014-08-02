(display ((lambda (x y)
            (((lambda (x) 
                (lambda (y) (* x y))) x) y)) 3 4))
