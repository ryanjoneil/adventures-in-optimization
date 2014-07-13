package main

import "fmt"

type Element float64
type Stack []Element

func (s *Stack) Push(e Element) {
    *s = append(*s, e)
}

func (s *Stack) Pop() Element {
    e := (*s)[len(*s)-1]
    *s = (*s)[:len(*s)-1]
    return e
}

func (s *Stack) Empty() bool {
    return len(*s) < 1
}

func main() {
    s := Stack([]Element{})

    for i := 0; i < 10; i++ {
        s.Push(Element(i))
    }

    for !s.Empty() {
        fmt.Println("pop:", s.Pop())
    }
}