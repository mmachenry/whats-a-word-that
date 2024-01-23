import { useState } from 'react'
import InfiniteScroll from 'react-infinite-scroll-component'
import Button from '@mui/material/Button'

interface IProps {
  host: string;
  category: string;
  pattern: string;
}

export default function MemberOutput (props: IProps) {
  const [pages, setPages] = useState<string[]>([])

  const loadMore = () => {
  }

  const hasMore = false
  const re = RegExp(props.pattern)
  const matches = pages.filter((page) => re.test(page))

// /*
  return (
    <>
      <p>{props.category} | {props.pattern}</p>
      {pages.map((item,idx) => (
        <div key={idx}>{idx} {item}</div>
      ))}
      <Button
        onClick={loadMore}
        disabled={hasMore}
        >
        Load more
      </Button>
    </>
  )
// */

 /*
  return (
    <>
        <p>{props.hasMore?"has more":"no more"}</p>
      <div
        id="scrollableDiv"
        style={{
          height: 300,
          overflow: 'auto',
          display: 'flex',
          flexDirection: 'column-reverse',
        }}
      >
        <InfiniteScroll
          scrollableTarget="scrollableDiv"
          style={{ display: 'flex', flexDirection: 'column' }}
          dataLength={props.members.length}
          next={props.next}
          hasMore={props.hasMore}
          loader={<h4>Loading...</h4>}
          endMessage={
            <p style={{ textAlign: 'center' }}>
              <b>Yay! You have seen it all</b>
            </p>
          }
        >
          {props.members.map((item,idx) => (
            <div key={idx}>{idx} {item}</div>
          ))}
        </InfiniteScroll>
      </div>
    </>
  )
// */
}
