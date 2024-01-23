import { useState } from 'react'
import CategorySelect from './components/CategorySelect'
import PatternInput from './components/PatternInput'
import MemberOutput from './components/MemberOutput'

const host = "en.wikipedia.org"

export default function App() {
  const [category, setCategory] = useState<string>("")
  const [pattern, setPattern] = useState<string>("")

  return (
    <>
      <CategorySelect host={host} onChange={setCategory} />
      <PatternInput onChange={setPattern} />
      <MemberOutput host={host} category={category} pattern={pattern} />
    </>
  )
}
