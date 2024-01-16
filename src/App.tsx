import { useState } from 'react'
import Autocomplete from '@mui/material/Autocomplete'
import TextField from '@mui/material/TextField'
import MemberOutput from './components/MemberOutput'
import axios from 'axios'

const wikiHost = "en.wikipedia.org"

function App() {
  const [categories, setCategories] = useState<string[]>([])
  const [category, setCategory] = useState<string>("")
  const [regex, setRegex] = useState<string>("")
  const [members, setMembers] = useState<string[]>([])
  const [continuation, setContinuation] = useState<string|null>(null)

  const re = RegExp(regex)
  const matches = members.filter((member) => re.test(member))

  const updateRegex = (event: React.ChangeEvent<HTMLInputElement>) => {
    const value = event.target.value
    setRegex(value)
  }

  const loadMembers = () => {
    let url = "https://" + wikiHost + "/w/api.php?action=query&list=categorymembers&origin=*&format=json&cmtitle=Category:" + category
    if (continuation) {
      url += "&cmcontinue=" + continuation
    }
    console.log(url)

    axios.get(url)
    .then((result) => {
      console.log(result)
      setContinuation(result.data.continue.cmcontinue)
      const newMembers = result.data.query.categorymembers.map(
        (m) => m.title
      )
      setMembers([...members, ...newMembers])
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
