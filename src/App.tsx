import { useState } from 'react'
import Autocomplete from '@mui/material/Autocomplete'
import TextField from '@mui/material/TextField'
import Button from '@mui/material/Button'
import MemberOutput from './components/MemberOutput'
import axios from 'axios'

const wikiHost = "en.wikipedia.org"

function App() {
  const [categories, setCategories] = useState<string[]>([])
  const [category, setCategory] = useState<string>("")
  const [regex, setRegex] = useState<string>("")
  const [pages, setPages] = useState<string[]>([])
  const [subCategories, setSubCategories] = useState<string[]>([])
  const [continuation, setContinuation] = useState<string|null>(null)

  const re = RegExp(regex)
  const matches = pages.filter((page) => re.test(page))

  const updateRegex = (event: React.ChangeEvent<HTMLInputElement>) => {
    const value = event.target.value
    setRegex(value)
  }

  const loadMembers = () => {
    let url = "https://" + wikiHost + "/w/api.php?action=query&list=categorymembers&origin=*&format=json&cmlimit=100&cmtitle=Category:" + category
    if (continuation) {
      url += "&cmcontinue=" + continuation
    }

    axios.get(url).then((result) => {
      setContinuation(result.data.continue?.cmcontinue)
      const newMembers = result.data.query.categorymembers
      const newSubCategories = newMembers.filter((item) => item.ns == 14).map((item) => item.title)
      const newPages = newMembers.filter((item) => item.ns == 0).map((item) => item.title)
      setPages([...pages, ...newPages])
      setSubCategories([...subCategories, newSubCategories])
    })
  }

  const onBlurCategory = () => {
    loadMembers()
  }

  const inputChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const value = event.target.value
    setCategory(value)

    axios.get(
      "https://" + wikiHost + "/w/api.php?action=query&list=allcategories&acprefix=" + value + "&origin=*&format=json",
    ).then((result) => {
      const matched = result.data.query.allcategories.map(
        (item) => item["*"]
      )
      setCategories(matched)
    })
  }

  return (
    <>
      <Autocomplete
        disablePortal
        onInputChange={inputChange}
        onBlur={onBlurCategory}
        options={categories}
        sx={{ width: 300 }}
        renderInput={(params) => <TextField {...params} label="Category" />}
      />

      <TextField
        sx={{ width: 300 }}
        label="Regex"
        onChange={updateRegex}
      />

      <p>contination: {continuation}</p>
      <Button onClick={loadMembers}>Load</Button>

      <MemberOutput
        members={matches}
        host={wikiHost}
        hasMore={continuation}
        next={loadMembers}
        />
    </>
  )
}

export default App
